Easy git deployment
===================

Straightforward, [Heroku][]-style, push-based deployment. Your deploys can become as simple as this:

    $ git push production master

To get started, install the "git-deploy" gem.

    gem install git-deploy

Only the person who is setting up deployment for the first time needs to install
the gem. You don't have to add it to your project's Gemfile.


Which app languages/frameworks are supported?
---------------------------------------------

Regardless of the fact that this tool is mostly written in Ruby, git-deploy can be useful for any kind of code that needs deploying on a remote server. The default scripts are suited for Ruby web apps, but can be edited to accommodate other frameworks.

Your deployment is customized with per-project callback scripts which can be written in any language.

The assumption is that you're deploying to a single host to which you connect over SSH using public/private key authentication.


Initial setup
-------------

1.  Create a git remote for where you'll push the code on your server. The name of this remote in the examples is "production", but it can be whatever you wish ("online", "website", or other).

    ```sh
    git remote add production "user@example.com:/apps/mynewapp"
    ```

    `/apps/mynewapp` is the directory where you want your code to reside on the
    remote server. If the directory doesn't exist, the next step creates it.

2.  Run the setup task:

    ```sh
    git-deploy setup -r "production"
    ```

    This will initialize the remote git repository in the deploy directory
    (`/apps/mynewapp` in the above example) and install the remote git hook.

3.  Run the init task:

    ```sh
    git-deploy init
    ```

    This generates default deploy callback scripts in the `deploy/` directory.
    You should check them in git because they are going to be executed on the
    server during each deploy.

4.  Push the code.

    ```sh
    git push production master
    ```

3.  Login to your server and manually perform necessary one-time administrative operations. This might include:
    * set up the Apache/nginx virtual host for this application;
    * check your `config/database.yml` and create the production database.


Everyday deployments
--------------------

If you've set your app correctly, visiting <http://example.com> in your browser
should show it up and running.

Now, subsequent deployments are done simply **by pushing to the branch that is
currently checked out on the remote**:

    git push production master

Because the deployments are performed with git, nobody else on the team needs to
install the "git-deploy" gem.

On every deploy, the default `deploy/after_push` script performs the following:

1. updates git submodules (if there are any);
2. runs `bundle install --deployment` if there is a Gemfile;
3. runs `rake db:migrate` if new migrations have been added;
4. clears cached CSS/JS assets in "public/stylesheets" and "public/javascripts";
5. restarts the web application.

You can customize all this by editing generated scripts in the `deploy/`
directory of your app.

Deployments are logged to `log/deploy.log` in your application's directory.


How it works
------------

The `git deploy setup` command installed a `post-receive` git hook in the remote
repository. This is how your code on the server is kept up to date. This script
checks out the latest version of your project from the current branch and
runs the following callback scripts:

* `deploy/setup` - on first push.
* `deploy/after_push` - on subsequent pushes. It in turn executes:
  * `deploy/before_restart`
  * `deploy/restart`
  * `deploy/after_restart`
* `deploy/rollback` - executed for `git deploy rollback`.

All of the callbacks are optional. These scripts are ordinary Unix executables.
The ones which get generated for you by `git deploy init` are written in shell
script and Ruby.


Extra commands
--------------

* `git deploy hooks` - Updates git hooks on the remote repository

* `git deploy log [N=20]` - Shows last 20 lines of deploy log on the server

* `git deploy rerun` - Re-runs the `deploy/after_push` callback as if a git push happened

* `git deploy restart` - Runs the `deploy/restart` callback

* `git deploy rollback` - Undo a deploy by checking out the previous revision,
  runs `deploy/rollback` if exists instead of `deploy/after_push`

* `git deploy upload <files>` - Copy local files to the remote app



  [heroku]: http://heroku.com/
