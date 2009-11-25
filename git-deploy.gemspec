Gem::Specification.new do |gem|
  gem.name    = 'git-deploy'
  gem.version = '0.3.0'
  gem.date    = Date.today.to_s
  
  gem.add_dependency 'capistrano', '~> 2.5.9'
  
  gem.summary = "Simple git push-based application deployment"
  gem.description = "A tool to install useful git hooks on your remote repository to enable push-based, Heroku-like deployment on your host."
  
  gem.authors  = ['Mislav Marohnić']
  gem.email    = 'mislav.marohnic@gmail.com'
  gem.homepage = 'http://github.com/mislav/git-deploy'
  
  gem.rubyforge_project = nil
  gem.has_rdoc = false
  
  gem.files = Dir['Rakefile', '{bin,lib,rails,test,spec}/**/*', 'README*', 'LICENSE*'] & `git ls-files`.split("\n")
end
