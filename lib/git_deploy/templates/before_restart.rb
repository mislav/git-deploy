#!/usr/bin/env ruby
oldrev, newrev = ARGV

def run(cmd)
  exit($?.exitstatus) unless system "umask 002 && #{cmd}"
end

def get_env
  case `hostname`
  when /obdev/
    'development'
  when /.local$/
    'local'
  else
    'production'
  end  
end

RACK_ENV    = ENV['RACK_ENV'] || get_env

use_bundler = File.file? 'Gemfile'
rake_cmd    = use_bundler ? 'bundle exec rake' : 'rake'

if use_bundler
  bundler_args = ['--deployment']
  BUNDLE_WITHOUT = ENV['BUNDLE_WITHOUT'] || 'development:test'
  bundler_args << '--without' << BUNDLE_WITHOUT unless BUNDLE_WITHOUT.empty?

  # update gem bundle
  run "bundle install #{bundler_args.join(' ')}"
end

if File.file? 'Rakefile'
  tasks = []

  # num_migrations = `git diff #{oldrev} #{newrev} --diff-filter=A --name-only -z db/migrations`.split("\0").size
  # run migrations if new ones have been added
  tasks << "db:migrate"

  # precompile assets
  # changed_assets = `git diff #{oldrev} #{newrev} --name-only -z app/assets`.split("\0")
  # tasks << "assets:precompile" if changed_assets.size > 0

  run "#{rake_cmd} #{tasks.join(' ')} RACK_ENV=#{RACK_ENV}" if tasks.any?
end

# clear cached assets (unversioned/ignored files)
run "git clean -x -f -- public/stylesheets public/javascripts"

# clean unversioned files from vendor/plugins (e.g. old submodules)
run "git clean -d -f -- vendor/plugins"

