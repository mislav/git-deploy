desc "generates .gemspec file"
task :gemspec do
  spec = Gem::Specification.new do |p|
    p.name = 'git-deploy'
    p.version = '0.2.0'

    p.summary     = "Simple git push-based application deployment"
    p.description = "git-deploy is a tool to install useful git hooks on your remote repository to enable git push-based, Heroku-like deployment on your host."

    p.author = 'Mislav Marohnić'
    p.email  = 'mislav.marohnic@gmail.com'
    p.homepage = 'http://github.com/mislav/git-deploy'

    p.add_dependency 'capistrano', '~> 2.5.9'
    
    p.files = FileList.new('Rakefile', '{bin,lib,sample,test,spec,rails}/**/*', 'README*', 'LICENSE*', 'CHANGELOG*')
    p.files &= `git ls-files -z`.split("\0")
                
    p.executables = Dir['bin/*'].map { |f| File.basename(f) }

    p.rubyforge_project = nil
    p.has_rdoc = false
  end
  
  spec_string = spec.to_ruby
  
  begin
    Thread.new { eval("$SAFE = 3\n#{spec_string}", binding) }.join 
  rescue
    abort "unsafe gemspec: #{$!}"
  else
    File.open("#{spec.name}.gemspec", 'w') { |file| file.write spec_string }
  end
end
