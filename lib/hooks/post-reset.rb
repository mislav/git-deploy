#!/usr/bin/ruby
RAILS_ENV = 'production'
oldrev, newrev = ARGV
$stdout.sync = true

# get a list of files that changed
changes = `git diff #{oldrev} #{newrev} --diff-filter=ACDMR --name-status`.split("\n")

# make a hash of files that changed and how they changed
changes_hash = changes.inject(Hash.new { |h, k| h[k] = [] }) do |hash, line|
  modifier, filename = line.split("\t", 2)
  hash[modifier] << filename
  hash
end

# create an array of files added, copied, modified or renamed
modified_files = %w(A C M R).inject([]) { |files, bit| files.concat changes_hash[bit] }
added_files = changes_hash['A'] # added
deleted_files = changes_hash['D'] # deleted
changed_files = modified_files + deleted_files # all
puts "files changed: #{changed_files.size}"

class Array
  # scans the list of files to see if any of them are under the given path
  def any_in_dir?(dir)
    if Array === dir
      exp = %r{^(?:#{dir.join('|')})/}
      any? { |file| file =~ exp }
    else
      dir += '/'
      any? { |file| file.index(dir) == 0 }
    end
  end
end

cached_assets_cleared = false

# detect modified asset dirs
asset_dirs = %w(public/stylesheets public/javascripts).select do |dir|
  # did any on the assets under this dir change?
  changed_files.any_in_dir?(dir)
end

unless asset_dirs.empty?
  # clear cached assets (unversioned/ignored files)
  deleted_assets = `git ls-files -z --other -- #{asset_dirs.join(' ')} | xargs -0 rm -v`.split("\n")
  unless deleted_assets.empty?
    puts "cleared: #{deleted_assets.join(', ')}"
    cached_assets_cleared = true
  end
end

# run migrations when new ones added
if new_migrations = added_files.any_in_dir?('db/migrate')
  system %(rake db:migrate RAILS_ENV=#{RAILS_ENV})
end

if modified_files.include?('.gitmodules')
  # sync submodule remote urls in case of changes
  system %(git submodule sync)
  # initialize new submodules
  system %(git submodule init)
end
# update existing submodules
system %(git submodule update)

# determine if app restart is needed
if cached_assets_cleared or new_migrations or changed_files.any_in_dir?(%w(app config lib public vendor))
  require 'fileutils'
  # tell Passenger to restart this app
  FileUtils.touch 'tmp/restart.txt'
  puts "restarting Passenger app"
end
