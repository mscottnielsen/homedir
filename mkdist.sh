#!/bin/env bash
#
# Script creates a tar of 'home directory' files that be used in
# in a 'home' directory. Symlink dot-files in $HOME to these files.
# Optionally includes "servers" git project w/ host env config's.
#

targ=../homedir.tgz
ask_rm=false
[ $# -gt 0 -a "$1" = "-i" ] && ask_rm=true

if [ -f $targ ] ; then
  $ask_rm && echo "** warning: file exists: $targ" && rm -i $targ || rm -f $targ
  [ -f $targ ] && exit 2
fi

filelist() {
  local d=$1
  [ $# -ne 1 -o ! -d ../$d ] \
     && echo "** error: dir does not exist: \"$d\"" 1>&2 \
     && return 2

  ( cd ../$d/  \
     && git pull --ff-only >/dev/null \
     && git ls-files | sed "s/^/$d\//" ) 2>/dev/null
}


mk_zOS() {
  local tmpdir=/tmp/tst.$LOGNAME.$$/
  local zfile=$(basename ${tarfile} .tgz).zOS.tgz
  mkdir -p $tmpdir \
     && cp -i $tarfile $tmpdir \
     && ( cd $tmpdir \
           && tar xzf $tarfile \
           && rm $tarfile \
           && find . -type f -exec sed -i '1 s/^.*bin\/bash.*$/\#\!\/bin\/env bash/' {} \;  \
           && tar czf $zfile * \
           && cd - )
  [ -f $tmpdir/$zfile ] && mv $tmpdir/$zfile .
  [ -d $tmpdir ] && rm -fr $tmpdir
}


[ ! -d ../homedir -o ! -d skel ] \
  && echo '** error: run script inside 'homedir' directory' && exit 2

h_files=$(filelist homedir)
s_files=$(filelist servers)

printf "
=====================================================================
== create tar: ${targ}
=====================================================================\n"

tarfile=$(basename $targ)
( cd .. && echo "** running: tar -vzcf ${tarfile} $(echo ${h_files:0:9}.. ${s_files:0:9}.. )"; )
( cd .. && tar --exclude=.git --exclude=.ade_path -czf ${tarfile} ${h_files} ${s_files}; )

[ -f $targ ] && printf "** created ${targ}\n" && cd .. && ls -l ${tarfile}

mk_zOS

