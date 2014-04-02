#!/bin/bash

scriptdir=$HOME/.local/share/nautilus/scripts

create_links() {
  local f targ
  cd $1
  shift
  for f ; do
    targ=$(basename "$f") 
    # if filename is "copy_to", name link "copy_to..."
    [ "${targ##*_}" = "to" ] && targ="${targ}..."
    ln -i -s "$f" "$targ"
  done
}

[ ! -d $scriptdir ] && echo "Nautilus script directory does not exist: $scriptdir" && exit 2

files=$(ls -d $PWD/scripts/* | egrep -v '\.old|~$|\.bak$')

[ "${#files}" -le 1 ] && echo "No matching scripts in to add to Nautilus: (script directory: $PWD/scripts)" && exit 2

create_links $scriptdir $files

