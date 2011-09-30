Easy git deployment
===================

Straightforward, [Heroku][]-style, push-based deployment. Your deploys will look like this:

    $ git push production master

Assumptions are that you are deploying to a single host. Also, that you have Phusion Passenger on the server running your application.

To get started, install the "git-deploy" gem.


Setup steps
-----------

1.  Create a git remote for where you'll push the code on your server. The name of this remote in the examples is "production", but it can be whatever you wish ("online", "website", or other).
    
        $ git remote add production user@example.com:/path/to/myapp
    
    The "/path/to/myapp" is the directory where your code will reside. It doesn't have to exist; it will be created for you during this setup.

2.  Run the setup task:
    
        $ git deploy setup -r production
    
    This will initialize the remote git repository in the target directory ("/path/to/myapp" in the above example), install the remote git hooks and push the master branch to the server.

3.  Login to your server and manually perform necessary one-time administrative operations. This might include:
    * set up the Apache/nginx virtual host for this application;
    * check your "config/database.yml" and create the production database.


Deployment
----------

After you've set everything up, visiting "http://example.com" in your browser should show your app up and running.

Now, subsequent deployments are done simply by pushing to the branch that is currently checked out on the remote:

    $ git push production master

Deployments are logged to "log/deploy.log" in your application.

On first push your server automatically:

1. creates the "log" and "tmp" directories;
2. copies "config/database.example.yml" to "config/database.yml".

On every subsequent deploy, the "post-reset" script analyzes changes and:

4. sync submodule urls if ".gitmodules" file has changed;
5. initialize and update submodules;
1. clears cached CSS/JS assets if any versioned files under "public/stylesheets" and "public/javascripts" have changed;
2. runs `bundle install --deployment` if Gemfile or Gemfile.lock have been changed
3. runs `rake db:migrate` if new migrations have been added;
6. `touch tmp/restart.txt` if app restart is needed.

Finally, these are the conditions that trigger the app restart:

1. some CSS/JS assets have been cleared;
2. the database schema has been migrated;
3. one or more files/submodules under "app", "config", "lib", "public", or "vendor" have changed.


How it works
------------

The "setup" task installed a couple of hooks in the remote git repository: "post-receive" and "post-reset". The former is a git hook which is invoked after every push to your server, while the latter is a *custom* hook that's called asynchronously by "post-receive" when we updated the deployment branch. This is how your working copy on the server is kept up-to-date.

It's worth knowing that "post-reset" is done **asynchronously from your push operation**. This is because migrating the database and updating submodules might take a long time and we don't want to wait for all that while we're doing a git push. But, this means that when the push is done, the server has *not yet restarted*. You might need to wait a few seconds or a minute.


  [heroku]: http://heroku.com/