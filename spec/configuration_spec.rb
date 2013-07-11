require 'rspec'
require 'git_deploy/configuration'

describe GitDeploy::Configuration do

  subject {
    mod = described_class
    obj = Object.new
    opt = options
    (class << obj; self; end).class_eval do
      include mod
      mod.private_instance_methods.each {|m| public m }
      define_method(:options) { opt }
    end
    obj
  }

  let(:options) { {:remote => 'production'} }

  def stub_git_config(cmd, value)
    subject.git_config[cmd] = value
  end

  def stub_remote_url(url, remote = options[:remote])
    stub_git_config("config --get-regexp 'remote.#{remote}.(push)?url'", url)
  end

  describe "extracting user/host from remote url" do
    context "ssh url" do
      before { stub_remote_url 'ssh://jon%20doe@example.com:88/path/to/app' }

      its(:host)        { should eq('example.com') }
      its(:remote_port) { should eq(88) }
      its(:remote_user) { should eq('jon doe') }
      its(:deploy_to)   { should eq('/path/to/app') }
    end

    context "scp-style" do
      before { stub_remote_url 'git@example.com:/path/to/app' }

      its(:host)        { should eq('example.com') }
      its(:remote_port) { should be_nil }
      its(:remote_user) { should eq('git') }
      its(:deploy_to)   { should eq('/path/to/app') }
    end
  end

end
