require 'thor'
require 'net/ssh'
require 'net/scp'

class GitDeploy < Thor
  LOCAL_DIR = File.expand_path('..', __FILE__)

  class_option :remote, :aliases => '-r', :type => :string, :default => 'origin'
  class_option :noop, :aliases => '-n', :type => :boolean, :default => false

  desc "setup", "Create the remote git repository, install git hooks, push the code"
  method_option :shared, :aliases => '-g', :type => :boolean, :default => true
  method_option :sudo, :aliases => '-s', :type => :boolean, :default => true
  def setup
    sudo_cmd = options.sudo? ? 'sudo' : ''
    
    run ["#{sudo_cmd} mkdir -p #{deploy_to}"] do |cmd|
      cmd << "#{sudo_cmd} chown $USER #{deploy_to}" if options.sudo?
      cmd << "chmod g+ws #{deploy_to}" if options.shared?
      cmd << "cd #{deploy_to}"
      cmd << "git init #{options.shared? ? '--shared' : ''}"
      cmd << "sed -i'' -e 's/master/#{branch}/' .git/HEAD" unless branch == 'master'
      cmd << "git config --bool receive.denyNonFastForwards false" if options.shared?
      cmd << "git config receive.denyCurrentBranch ignore"
    end
    
    invoke :hooks
    system 'git', 'push', options[:remote], branch
  end

  desc "hooks", "Installs git hooks to the remote repository"
  def hooks
    hooks_dir = File.join(LOCAL_DIR, 'hooks')
    remote_dir = "#{deploy_to}/.git/hooks"

    scp_upload "#{hooks_dir}/post-receive.rb" => "#{remote_dir}/post-receive",
               "#{hooks_dir}/post-reset.rb" => "#{remote_dir}/post-reset"

    run "chmod +x #{remote_dir}/post-receive #{remote_dir}/post-reset"
  end
  
  desc "restart", "Restarts the application"
  def restart
    run "touch #{deploy_to}/tmp/restart.txt"
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
  
  private
  
  def host
    extract_host_and_user unless defined? @host
    @host
  end
  
  def remote_user
    extract_host_and_user unless defined? @user
    @user
  end
  
  def extract_host_and_user
    info = remote_url.split(':').first.split('@')
    if info.size < 2
      @user, @host = `whoami`.chomp, info.first
    else
      @user, @host = *info
    end
  end
  
  def deploy_to
    @deploy_to ||= remote_url.split(':').last
  end
  
  def branch
    'master'
  end
  
  def run(cmd = nil)
    cmd = yield(cmd) if block_given?
    cmd = cmd.join(' && ') if Array === cmd
    ssh_exec cmd
  end
  
  def system(*args)
    puts "[local] $ " + args.join(' ').gsub(' && ', " && \\\n  ")
    super unless options.noop?
  end
  
  def ssh_exec(cmd)
    puts "[#{options[:remote]}] $ " + cmd.gsub(' && ', " && \\\n  ")

    ssh_connection.exec!(cmd) do |channel, stream, data|
      case stream
      when :stdout then $stdout.puts data
      when :stderr then $stderr.puts data
      else
        raise "unknown stream: #{stream.inspect}"
      end
    end unless options.noop?
  end
  
  def scp_upload(files)
    channels = []
    files.each do |local, remote|
      puts "FILE: [local] #{local.sub(LOCAL_DIR + '/', '')}  ->  [#{options[:remote]}] #{remote}"
      channels << ssh_connection.scp.upload(local, remote) unless options.noop?
    end
    channels.each { |c| c.wait }
  end
  
  def ssh_connection
    @ssh ||= begin
      ssh = Net::SSH.start(host, remote_user)
      at_exit { ssh.close }
      ssh
    end
  end
  
  def git_config
    @git_config ||= Hash.new do |cache, cmd|
      git = ENV['GIT'] || 'git'
      out = `#{git} #{cmd}`
      if $?.success? then cache[cmd] = out.chomp
      else cache[cmd] = nil
      end
      cache[cmd]
    end
  end
  
  def remote_urls(remote)
    git_config["config --get-all remote.#{remote}.url"].to_s.split("\n")
  end
  
  def remote_url(remote = options[:remote])
    @remote_url ||= {}
    @remote_url[remote] ||= begin
      url = remote_urls(remote).first
      if url.nil?
        abort "Error: Remote url not found for remote #{remote.inspect}"
      elsif url =~ /\bgithub\.com\b/
        abort "Error: Remote url for #{remote.inspect} points to GitHub. Can't deploy there!"
      end
      url
    end
  end

  def current_branch
    git_config['symbolic-ref -q HEAD']
  end

  def tracked_branch
    branch = current_branch && tracked_for(current_branch)
    normalize_branch(branch) if branch
  end

  def normalize_branch(branch)
    branch.sub('refs/heads/', '')
  end

  def remote_for(branch)
    git_config['config branch.%s.remote' % normalize_branch(branch)]
  end

  def tracked_for(branch)
    git_config['config branch.%s.merge' % normalize_branch(branch)]
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
