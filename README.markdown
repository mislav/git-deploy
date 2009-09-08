Capistrano strategy for smart git deployment
============================================

Let's set up a straightforward, [Heroku][]-style, push-based deployment, shall we? The goal is that our deployments look like this:

    $ git push origin production

Assumptions are that you are using git for your Rails app and Passenger on the server. For now, we're going to deploy on a single host.


Setup steps
-----------

1.  Create a git remote for where you'll push the code on your server. The name of this remote in the examples is "origin", but it can be whatever you wish ("online", "website", or other).
    
        $ git remote add origin user@example.com:/path/to/myapp
    
    The "/path/to/myapp" is the directory where your code will reside. It doesn't have to exist; it will be created for you during this setup.

2.  Create/overwrite the following files in your project:
    
    **config/deploy.rb** (entire file):
    
        # set to the name of git remote you intend to deploy to
        set :remote, "origin"
        # specify the deployment branch
        set :branch, "master"
        # sudo will only be used to create the deployment directory
        set :use_sudo, true
        # the remote host is read automatically from your git remote specification
        server remote_host, :app, :web, :db, :primary => true
    
    **Capfile**:
    
        require 'git_deploy'
        load 'config/deploy'
    
    Test it by running `cap -T`. You should see several deploy tasks listed.

3.  Run the setup task:
    
        $ cap deploy:setup
    
    This will initialize a git repository in the target directory, install the push hook and push the branch you specified to the server.

4.  Login to your server to perform necessary one-time administrative operations. This might include:
    * set up the Apache/nginx virtual host for this application;
    * check out the branch which you will push production code into (often this is "production");
    * check your config/database.yml and create or import the production database.


Deployment
----------

After you've set everything up, visiting "http://example.com" in your browser should show your app up and running. Subsequent deployments are done simply by pushing to the branch that is currently checked out on our server (see step 4.). The branch is by default "master", but it's suggested to have production code in another branch like "production" or other. This, of course, depends on your git workflow.

We've reached our goal; our deployment now looks like:

    $ git push origin production

In fact, running "cap deploy" does exactly this. So what does it do?

The "deploy:setup" task installed a couple of hooks in the remote git repository: "post-receive" and "post-reset". The former is a git hook which is invoked after every push to your server, while the latter is a *custom* hook that's called asynchronously by "post-receive" when we updated the deployment branch. This is how your working copy on the server is kept up-to-date.

Thus, on first push your server automatically:

1. creates the "log" and "tmp" directories;
2. copies "config/database.example.yml" or "config/database.yml.example" to "config/database.yml".

On every subsequent deploy, the "post-reset" script analyzes changes and:

1. clears cached css and javascript assets if any versioned files under "public/stylesheets" and "public/javascripts" have changed, respectively;
2. runs "rake db:migrate" if new migrations have been added;
3. sync submodule urls if ".gitmodules" file has changed;
4. initialize and update submodules;
5. touches "tmp/restart.txt" if app restart is needed.

Finally, these are the conditions that dictate an app restart:

1. css/javascript assets have been cleared;
2. the database has migrated;
3. one or more files/submodules under "app", "config", "lib", "public", or "vendor" changed.


In the future
-------------

Next steps for this library are:

* Support for deployment on multiple hosts. This is a slightly different strategy based on git pull instead of push; something in-between regular "remote cache" strategy and the aforementioned
* Better configurability
* Steps forward to supporting more existing 3rd-party Capistrano tasks, like that of the EngineYard gem
* Support for multiple environments on the same server: production, staging, etc.
* Automatic submodule conflict resolving


[heroku]: http://heroku.com/