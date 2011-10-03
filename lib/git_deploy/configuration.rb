class GitDeploy
  module Configuration
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
end
