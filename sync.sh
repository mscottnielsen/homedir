#!/bin/bash

#############################################################################
# to keep upstream (github) in sync with local fork (orahub)
#############################################################################

## clone the fork...
# $ git clone git@orahub.oraclecorp.com:mike_nielsen/homedir.git

## ..or, get latest if already cloned
git pull

## list remote
# $ git remote -v 
# origin   git@orahub.oraclecorp.com:mike_nielsen/homedir.git (fetch)
# origin   git@orahub.oraclecorp.com:mike_nielsen/homedir.git (push)

## add the original upstream repo
# $ git remote add upstream  https://github.com/mscottnielsen/homedir.git 
# $ git remote -v 
# origin   git@orahub.oraclecorp.com:mike_nielsen/homedir.git (fetch)
# origin   git@orahub.oraclecorp.com:mike_nielsen/homedir.git (push)
# upstream https://github.com/mscottnielsen/homedir.git (fetch)
# upstream https://github.com/mscottnielsen/homedir.git (push)


## get updates from original (set proxy if necessary)
. ~/bin/set_proxy.sh 
git fetch upstream

## merge those upstream changes with the fork
git merge upstream/master

## push changes to fork
git push origin

