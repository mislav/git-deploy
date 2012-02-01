Easy git deployment
===================

Straightforward, [Heroku][]-style, push-based deployment. Your deploys will look like this:

    $ git push production master

To get started, install the "git-deploy" gem.

    $ gem install git-deploy


What application frameworks/languages are supported?
----------------------------------------------------

Regardless of the fact that this tool is mostly written in Ruby, git-deploy can be useful for any kind of code that needs deploying on a remote server. The default scripts are suited for Ruby web apps, but can be edited to accommodate other frameworks.

Your deployment is customized with per-project callback scripts which can be written in any language.

The assumption is that you're deploying to a single host to which you connect over SSH using public/private key authentication.


Setup steps
-----------

1.  Create a git remote for where you'll push the code on your server. The name of this remote in the examples is "production", but it can be whatever you wish ("online", "website", or other).
    
        $ git remote add production user@example.com:/path/to/myapp
    
    The "/path/to/myapp" is the directory where your code will reside. It doesn't have to exist; it will be created for you during this setup.

2.  Run the setup task:
    
        $ git deploy setup -r production
    
    This will initialize the remote git repository in the target directory ("/path/to/myapp" in the above example) and install the remote git hooks.

    The target directory must already exists otherwise SCP will throw errors.

3.  Run the init task:
    
        $ git deploy init
    
    This generates default deploy callback scripts in the "deploy/" directory. You must check them in version control. They are going to be executed on the server on each deploy.

4.  Push the code.

        $ git push production master

3.  Login to your server and manually perform necessary one-time administrative operations. This might include:
    * set up the Apache/nginx virtual host for this application;
    * check your "config/database.yml" and create the production database.


Deployment
----------

If you've set your app correctly, visiting "http://example.com" in your browser should show it up and running.

Now, subsequent deployments are done simply by pushing to the branch that is currently checked out on the remote:

    $ git push production master

Because the deployments are done with git, not everyone on the team had to install git-deploy. Just the person who was doing the setup.

Deployments are logged to "log/deploy.log" in your application.

On every deploy, the "deploy/after_push" script performs the following:

1. updates git submodules (if there are any);
2. runs `bundle install --deployment` if there is a Gemfile;
3. runs `rake db:migrate` if new migrations have been added;
4. clears cached CSS/JS assets in "public/stylesheets" and "public/javascripts";
5. restarts the web application.

You can customize all of this by editing scripts in the "deploy/" directory of your app.

How it works
------------

The "setup" task installed a "post-receive" hook in the remote git repository. This is how your working copy on the server is kept up to date. This hook, after checking out latest code, asynchronously dispatches to "deploy/after_push" script in your application. This script executes on the server and also calls "deploy/before_restart", "restart", and "after_restart" callbacks if they are present.

These scripts are ordinary unix executable files. The ones which are generated for you are written in shell script and Ruby.

It's worth remembering that "after_push" is done **asynchronously from your git push**. This is because migrating the database and updating submodules might take a long time and you don't want to wait for all that during a git push. But, this means that when the push is done, the server has *not yet restarted*. You might need to wait a few seconds or a minute.


  [heroku]: http://heroku.com/