#!/usr/bin/env bash
if [ "$GIT_DIR" = "." ]; then
  # The script has been called as a hook; chdir to the working copy
  cd ..
  GIT_DIR=.git
  export GIT_DIR
fi

# try to obtain the usual system PATH
if [ -f /etc/profile ]; then
  PATH=$(source /etc/profile; echo $PATH)
  export PATH
fi

# get the current branch
head="$(git symbolic-ref HEAD)"
# abort if we're on a detached head
[ "$?" != "0" ] && exit 1

# read the STDIN to detect if this push changed the current branch
while read oldrev newrev refname
do
  [ "$refname" = "$head" ] && break
done
# abort if there's no update, or in case the branch is deleted
[ -z "${newrev//0}" ] && exit

# check out the latest code into the working copy
umask 002
git reset --hard

logfile=log/deploy.log
restart=tmp/restart.txt

if [ -z "${oldrev//0}" ]; then
  # this is the first push; this branch was just created
  mkdir -p log tmp
  chmod 0775 log tmp
  touch $logfile $restart
  chmod 0664 $logfile $restart

  # init submodules
  git submodule update --init | tee -a $logfile
else
  # log timestamp
  echo ==== $(date) ==== >> $logfile

  # execute the deploy hook in background
  [ -x deploy/after_push ] && deploy/after_push $oldrev $newrev 2>&1 | tee -a $logfile
fi
