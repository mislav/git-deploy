#!/usr/bin/env ruby
RAILS_ENV = 'production'
oldrev, newrev = ARGV
$stdout.sync = true

def parse_configuration(file)
  config = {}
  current = nil

  File.open(file).each_line do |line|
    case line
    when /^\[(\w+)(?: "(.+)")\]/
      key, subkey = $1, $2
      current = (config[key] ||= {})
      current = (current[subkey] ||= {}) if subkey
    else
      key, value = line.strip.split(' = ')
      current[key] = value
    end
  end
  
  config
end

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

cached_assets_cleared = false

# detect modified asset dirs
asset_dirs = %w(public/stylesheets public/javascripts).select do |dir|
  # did any on the assets under this dir change?
  changed_files.any_in_dir?(dir)
end

unless asset_dirs.empty?
  # clear cached assets (unversioned/ignored files)
  system %(git clean -x -f -- #{asset_dirs.join(' ')})
  cached_assets_cleared = true
end

if changed_files.include?('Gemfile') || changed_files.include?('Gemfile.lock')
  # update bundled gems if manifest file has changed
  system %(umask 002 && bundle install --deployment)
end

# run migrations when new ones added
if new_migrations = added_files.any_in_dir?('db/migrate')
  system %(umask 002 && rake db:migrate RAILS_ENV=#{RAILS_ENV})
end

if modified_files.include?('.gitmodules')
  # initialize new submodules
  system %(umask 002 && git submodule init)
  # sync submodule remote urls in case of changes
  config = parse_configuration('.gitmodules')

  if config['submodule']
    config['submodule'].values.each do |submodule|
      path = submodule['path']
      subconf = "#{path}/.git/config"

      if File.exists? subconf
        old_url = `git config -f "#{subconf}" remote.origin.url`.chomp
        new_url = submodule['url']
        unless old_url == new_url
          puts "changing #{path.inspect} URL:\n  #{old_url.inspect} → #{new_url.inspect}"
          `git config -f "#{subconf}" remote.origin.url "#{new_url}"`
        end
      else
        $stderr.puts "a submodule in #{path.inspect} doesn't exist"
      end
    end
  end
end
# update existing submodules
system %(umask 002 && git submodule update)

# clean unversioned files from vendor (e.g. old submodules)
system %(git clean -d -f vendor)

# determine if app restart is needed
if cached_assets_cleared or new_migrations or !File.exists?('config/environment.rb') or
    changed_files.any_in_dir?(%w(app config lib public vendor))
  require 'fileutils'
  # tell Passenger to restart this app
  FileUtils.touch 'tmp/restart.txt'
  puts "restarting Passenger app"
end
