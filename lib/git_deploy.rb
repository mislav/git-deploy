require 'thor'
require 'net/ssh'
require 'net/scp'

class GitDeploy < Thor
  LOCAL_DIR = File.expand_path('..', __FILE__)

  require 'git_deploy/configuration'
  require 'git_deploy/ssh_methods'
  include Configuration
  include SSHMethods

  class_option :remote, :aliases => '-r', :type => :string, :default => 'origin'
  class_option :noop, :aliases => '-n', :type => :boolean, :default => false

  desc "init", "Generates deployment customization scripts for your app"
  def init
    require 'git_deploy/generator'
    Generator::start([])
  end

  desc "setup", "Create the remote git repository and install push hooks for it"
  method_option :shared, :aliases => '-g', :type => :boolean, :default => true
  method_option :sudo, :aliases => '-s', :type => :boolean, :default => true
  def setup
    sudo = options.sudo? ? "#{sudo_cmd} " : ''

    unless run_test("test -x #{deploy_to}")
      run ["#{sudo}mkdir -p #{deploy_to}"] do |cmd|
        cmd << "#{sudo}chown $USER #{deploy_to}" if options.sudo?
        cmd
      end
    end

    run [] do |cmd|
      cmd << "chmod g+ws #{deploy_to}" if options.shared?
      cmd << "cd #{deploy_to}"
      cmd << "git init #{options.shared? ? '--shared' : ''}"
      cmd << "sed -i'' -e 's/master/#{branch}/' .git/HEAD" unless branch == 'master'
      cmd << "git config --bool receive.denyNonFastForwards false" if options.shared?
      cmd << "git config receive.denyCurrentBranch ignore"
    end

    invoke :hooks
  end

  desc "hooks", "Installs git hooks to the remote repository"
  def hooks
    hooks_dir = File.join(LOCAL_DIR, 'hooks')
    remote_dir = "#{deploy_to}/.git/hooks"

    scp_upload "#{hooks_dir}/post-receive.sh" => "#{remote_dir}/post-receive"
    run "chmod +x #{remote_dir}/post-receive"
  end
  
  desc "restart", "Restarts the application on the server"
  def restart
    run "cd #{deploy_to} && deploy/restart | tee -a log/deploy.log"
  end

  desc "rollback", "Rolls back the checkout to before the last push"
  def rollback
    run "cd #{deploy_to} && git reset --hard ORIG_HEAD"
    invoke :restart
  end

  desc "log [n=20]", "Shows the last part of the deploy log on the server"
  def log(n = 20)
    run "tail -n#{n} #{deploy_to}/log/deploy.log"
  end

  desc "upload <files>", "Copy local files to the remote app"
  def upload(*files)
    files = files.map { |f| Dir[f.strip] }.flatten
    abort "Error: Specify at least one file to upload" if files.empty?

    scp_upload files.inject({}) { |all, file|
      all[file] = File.join(deploy_to, file)
      all
    }
  end
end

__END__
Multiple hosts:
# deploy:
  invoke :code
  command = ["cd #{deploy_to}"]
  command << ".git/hooks/post-reset `cat .git/ORIG_HEAD` HEAD 2>&1 | tee -a log/deploy.log"

# code:
command = ["cd #{deploy_to}"]
command << source.scm('fetch', remote, "+refs/heads/#{branch}:refs/remotes/origin/#{branch}")
command << source.scm('reset', '--hard', "origin/#{branch}")
