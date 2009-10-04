# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{git-deploy}
  s.version = "0.2.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Mislav Marohni\304\207"]
  s.date = %q{2009-10-04}
  s.description = %q{git-deploy is a tool to install useful git hooks on your remote repository to enable git push-based, Heroku-like deployment on your host.}
  s.email = %q{mislav.marohnic@gmail.com}
  s.files = ["Rakefile", "lib/git_deploy.rb", "lib/hooks/post-receive.rb", "lib/hooks/post-reset.rb", "README.markdown"]
  s.homepage = %q{http://github.com/mislav/git-deploy}
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.5}
  s.summary = %q{Simple git push-based application deployment}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<capistrano>, ["~> 2.5.9"])
    else
      s.add_dependency(%q<capistrano>, ["~> 2.5.9"])
    end
  else
    s.add_dependency(%q<capistrano>, ["~> 2.5.9"])
  end
end
