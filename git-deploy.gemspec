# encoding: utf-8
Gem::Specification.new do |gem|
  gem.name    = 'git-deploy'
  gem.version = '0.6.1'
  gem.executables = %w[ git-deploy ]

  gem.add_dependency 'thor', '0.14.6'
  gem.add_dependency 'net-ssh', '~> 2.6'
  gem.add_dependency 'net-scp', '~> 1.1'

  gem.summary = "Simple git push-based application deployment"
  gem.description = "A tool to install useful git hooks on your remote repository to enable push-based, Heroku-like deployment on your host."

  gem.authors  = ['Mislav Marohnić']
  gem.email    = 'mislav.marohnic@gmail.com'
  gem.homepage = 'https://github.com/mislav/git-deploy#readme'
  gem.license  = 'MIT'

  gem.files = Dir['Rakefile', '{bin,lib,man,test,spec}/**/*', 'README*', 'LICENSE*']
end
