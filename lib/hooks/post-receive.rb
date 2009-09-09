#!/usr/bin/ruby
if ENV['GIT_DIR'] == '.'
  # this means the script has been called as a hook, not manually.
  # get the proper GIT_DIR so we can descend into the working copy dir;
  # if we don't then `git reset --hard` doesn't affect the working tree.
  Dir.chdir('..')
  ENV['GIT_DIR'] = '.git'
end

# find out the current branch
head = File.read('.git/HEAD').chomp
# abort if we're on a detached head
exit unless head.sub!('ref: ', '')

oldrev = newrev = nil
null_ref = '0' * 40

# read the STDIN to detect if this push changed the current branch
while newrev.nil? and gets
  # each line of input is in form of "<oldrev> <newrev> <refname>"
  revs = $_.split
  oldrev, newrev = revs if head == revs.pop
end

# abort if there's no update, or in case the branch is deleted
exit if newrev.nil? or newrev == null_ref

# update the working copy
`git reset --hard`

if oldrev == null_ref
  # this is the first push; this branch was just created
  require 'fileutils'
  FileUtils.mkdir_p %w(log tmp)
  config = 'config/database.yml'
  
  unless File.exists?(config)
    # install the database config from the example file
    example = ['config/database.example.yml', config + '.example'].find { |f| File.exists? f }
    FileUtils.cp example, config if example
  end
else
  logfile = 'log/deploy.log'
  # log timestamp
  File.open(logfile, 'a') { |log| log.puts "==== #{Time.now} ====" }
  # start the post-reset hook in background
  system %(nohup .git/hooks/post-reset #{oldrev} #{newrev} 1>>#{logfile} 2>>#{logfile} &)
end
