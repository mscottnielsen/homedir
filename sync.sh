#!/bin/bash

#############################################################################
# How to make changes, pushing to upstream (github) by default,
# and keeping that in sync with local intranet fork.
#
# (This is more just notes for commands to run than an actual script.)
#############################################################################

## clone the local intranet fork...
# $ git clone git@orahub.oraclecorp.com:mike_nielsen/homedir.git

## list remote:
# $ git remote -v
# origin   git@orahub.oraclecorp.com:mike_nielsen/homedir.git (fetch)
# origin   git@orahub.oraclecorp.com:mike_nielsen/homedir.git (push)

## add the original upstream repo (github)
# $ git remote add upstream  https://github.com/mscottnielsen/homedir.git

## verify:
# $ git remote -v
# origin   git@orahub.oraclecorp.com:mike_nielsen/homedir.git (fetch)
# origin   git@orahub.oraclecorp.com:mike_nielsen/homedir.git (push)
# upstream https://github.com/mscottnielsen/homedir.git (fetch)
# upstream https://github.com/mscottnielsen/homedir.git (push)

#############################################################################
# make changes as desired, but prefer to push them to the upstream source (github).
# note that this example isn't pushing anything to the internal intranet fork.
#############################################################################

## make changes and push to upstream:
### for each file modified; do
###    git add path/to/file
###    git commit -m 'message' path/to/file
###  done
###  git push -v -u upstream master

#############################################################################
# to keep upstream (github) in sync with local intranet fork
#############################################################################

## pull latest from intranet fork (may have to merge, if any changes)
git pull --ff-only -v origin/master

## get latest updates from original upstream repo (set proxy if necessary)
. ~/bin/set_proxy.sh
git fetch -v upstream

## merge those upstream changes with the intranet fork
git merge -v upstream/master

## push changes to intranet fork
git push -v origin

