require 'capistrano/recipes/deploy/scm/git'

Capistrano::Configuration.instance(true).load do
  def _cset(name, *args, &block)
    unless exists?(name)
      set(name, *args, &block)
    end
  end

  _cset(:application) { abort "Please specify the name of your application, set :application, 'foo'" }
  _cset :remote,   "origin"
  _cset :branch,   "master"
  _cset(:revision) { branch }
  _cset(:source)   { Capistrano::Deploy::SCM::Git.new(self) }

  _cset(:remote_url)  { `#{ source.local.scm('config', "remote.#{remote}.url") }`.chomp }
  _cset(:remote_host) { remote_url.split(':', 2).first }
  _cset(:deploy_to)   { exists?(:repository) ? "/u/apps/#{application}" : remote_url.split(':', 2).last }
  _cset(:run_method)  { fetch(:use_sudo, true) ? :sudo : :run }

  # If :run_method is :sudo (or :use_sudo is true), this executes the given command
  # via +sudo+. Otherwise is uses +run+. If :as is given as a key, it will be
  # passed as the user to sudo as, if using sudo. If the :as key is not given,
  # it will default to whatever the value of the :admin_runner variable is,
  # which (by default) is unset.
  def try_sudo(*args)
    options = args.last.is_a?(Hash) ? args.pop : {}
    command = args.shift
    raise ArgumentError, "too many arguments" if args.any?

    as = options.fetch(:as, fetch(:admin_runner, nil))
    via = fetch(:run_method, :sudo)
    if command
      invoke_command(command, :via => via, :as => as)
    elsif via == :sudo
      sudo(:as => as)
    else
      ""
    end
  end

  namespace :deploy do
    desc "Deploys your project."
    task :default do
      push
    end

    task :push do
      system source.local.scm('push', remote, "#{revision}:#{branch}")
    end

    desc "Prepares servers for deployment."
    task :setup do
      command = ["#{try_sudo} mkdir -p #{deploy_to}"]
      command << "#{try_sudo} chown $USER #{deploy_to}" if fetch(:run_method, :sudo) == :sudo
      command << "cd #{deploy_to}"
      command << "chmod g+w ."
      command << "git init"
      command << "echo 'ref: refs/heads/#{branch}' > .git/HEAD" unless branch == 'master'
      command << "rm .git/hooks/*"
      command << "git config receive.denyCurrentBranch ignore"
      run command.join(' && ')

      install_hooks
      push
    end

    task :install_hooks do
      dir = File.dirname(__FILE__) + '/hooks'
      remote_dir = "#{deploy_to}/.git/hooks"

      top.upload "#{dir}/post-receive.rb", "#{remote_dir}/post-receive"
      top.upload "#{dir}/post-reset.rb", "#{remote_dir}/post-reset"
      run "chmod +x #{remote_dir}/*"
    end

    desc "Restarts your Passenger application."
    task :restart, :roles => :app do
      run "touch #{deploy_to}/tmp/restart.txt"
    end
  end
end