#!/usr/bin/env ruby
oldrev, newrev = ARGV

def run(cmd)
  exit($?.exitstatus) unless system "umask 002 && #{cmd}"
end

RAILS_ENV   = ENV['RAILS_ENV'] || 'production'
use_bundler = File.file? 'Gemfile'
rake_cmd    = use_bundler ? 'bundle exec rake' : 'rake'

if use_bundler
  bundler_args = ['--deployment']
  BUNDLE_WITHOUT = ENV['BUNDLE_WITHOUT'] || 'development:test'
  bundler_args << '--without' << BUNDLE_WITHOUT unless BUNDLE_WITHOUT.empty?

  # update gem bundle
  gemfile_changed = `git diff #{oldrev} #{newrev} --name-only`.include?("Gemfile")
  run "bundle install #{bundler_args.join(' ')}" if gemfile_changed
end

if File.file? 'Rakefile'
  new_migration = `git diff #{oldrev} #{newrev} --diff-filter=A --name-only`.include?("migrate")
  # run migrations if new ones have been added
  run "#{rake_cmd} db:migrate RAILS_ENV=#{RAILS_ENV}" if new_migration

  # run asset precompile
  assets_changed = `git diff #{oldrev} #{newrev} --name-only`.include?("asset")
  run "#{rake_cmd} assets:precompile RAILS_ENV=#{RAILS_ENV}" if assets_changed
end

# clear cached assets (unversioned/ignored files)
run "git clean -x -f -- public/stylesheets public/javascripts"

# clean unversioned files from vendor/plugins (e.g. old submodules)
run "git clean -d -f -- vendor/plugins"
