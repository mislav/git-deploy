require 'capistrano/recipes/deploy/scm/git'

Capistrano::Configuration.instance(true).load do
  def _cset(name, *args, &block)
    unless exists?(name)
      set(name, *args, &block)
    end
  end

  _cset(:application) { abort "Please specify the name of your application, set :application, 'foo'" }
  _cset :remote, "origin"
  _cset :branch, "master"

  _cset(:multiple_hosts) { roles.values.map{ |v| v.servers}.flatten.uniq.size > 1 }
  _cset(:repository)  { `#{ source.local.scm('config', "remote.#{remote}.url") }`.chomp }
  _cset(:remote_host) { repository.split(':', 2).first }
  _cset(:deploy_to)   { repository.split(':', 2).last }
  _cset(:run_method)  { fetch(:use_sudo, true) ? :sudo : :run }
  _cset :group_writeable, false

  _cset(:current_branch) { File.read('.git/HEAD').chomp.split(' refs/heads/').last }
  _cset(:revision) { branch }
  _cset(:source)   { Capistrano::Deploy::SCM::Git.new(self) }

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
    
    if command
      invoke_command(command, :via => run_method, :as => as)
    elsif :sudo == run_method
      sudo(:as => as)
    else
      ""
    end
  end

  namespace :deploy do
    desc "Deploys your project."
    task :default do
      unless multiple_hosts
        push
      else
        code
        command = ["cd #{deploy_to}"]
        command << ".git/hooks/post-reset `cat .git/ORIG_HEAD` HEAD 2>&1 | tee -a log/deploy.log"
        
        run command.join(' && ')
      end
    end

    task :push do
      system source.local.scm('push', remote, "#{revision}:#{branch}")
    end

    task :code do
      command = ["cd #{deploy_to}"]
      command << source.scm('fetch', remote, "+refs/heads/#{branch}:refs/remotes/origin/#{branch}")
      command << source.scm('reset', '--hard', "origin/#{branch}")
      
      run command.join(' && ')
    end

    desc "Prepares servers for deployment."
    task :setup do
      shared = fetch(:group_writeable)
      
      command = ["#{try_sudo} mkdir -p #{deploy_to}"]
      command << "#{try_sudo} chown $USER #{deploy_to}" if :sudo == run_method
      command << "cd #{deploy_to}"
      command << "chmod g+w ." if shared
      command << "git init #{shared ? '--shared' : ''}"
      command << "sed -i'' -e 's/master/#{branch}/' .git/HEAD" unless branch == 'master'
      command << "git config --bool receive.denyNonFastForwards false" if shared
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
      run "chmod +x #{remote_dir}/post-receive #{remote_dir}/post-reset"
    end

    desc "Restarts your Passenger application."
    task :restart, :roles => :app do
      run "touch #{deploy_to}/tmp/restart.txt"
    end

    desc <<-DESC
      Copy files to the currently deployed version. Use a comma-separated \
      list in FILES to specify which files to upload.

      Note that unversioned files on your server are likely to be \
      overwritten by the next push. Always persist your changes by committing.

        $ cap deploy:upload FILES=templates,controller.rb
        $ cap deploy:upload FILES='config/apache/*.conf'
    DESC
    task :upload do
      files = (ENV["FILES"] || "").split(",").map { |f| Dir[f.strip] }.flatten
      abort "Please specify at least one file or directory to update (via the FILES environment variable)" if files.empty?

      files.each { |file| top.upload(file, File.join(deploy_to, file)) }
    end
  end
end