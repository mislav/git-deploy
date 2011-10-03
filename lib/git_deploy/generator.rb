require 'thor/group'

class GitDeploy::Generator < Thor::Group
  include Thor::Actions

  def self.source_root
    File.expand_path('../templates', __FILE__)
  end

  def copy_main_hook
    copy_hook 'after_push.sh', 'deploy/after_push'
  end

  def copy_restart_hook
    copy_hook 'restart.sh', 'deploy/restart'
  end

  def copy_restart_callbacks
    copy_hook 'before_restart.rb', 'deploy/before_restart'
  end

  private

  def copy_hook(template, destination)
    copy_file template, destination
    chmod destination, 0744 unless File.executable? destination
  end
end
