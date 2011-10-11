#!/usr/bin/env ruby
oldrev, newrev = ARGV

def run(cmd)
  exit($?.exitstatus) unless system "umask 002 && #{cmd}"
end

RAILS_ENV      = ENV['RAILS_ENV'] || 'production'
use_bundler    = File.file? 'Gemfile'
rake_cmd       = use_bundler ? 'bundle exec rake' : 'rake'
BUNDLE_WITHOUT = ENV['BUNDLE_WITHOUT'] || 'development test' if use_bundler

# update gem bundle
run "bundle install --deployment --without #{BUNDLE_WITHOUT}" if use_bundler

if File.file? 'Rakefile'
  num_migrations = `git diff #{oldrev} #{newrev} --diff-filter=A --name-only`.split("\n").size
  # run migrations if new ones have been added
  run "#{rake_cmd} db:migrate RAILS_ENV=#{RAILS_ENV}" if num_migrations > 0
end

# clear cached assets (unversioned/ignored files)
run "git clean -x -f -- public/stylesheets public/javascripts"

# clean unversioned files from vendor/plugins (e.g. old submodules)
run "git clean -d -f -- vendor/plugins"
