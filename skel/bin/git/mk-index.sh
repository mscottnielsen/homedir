#!/bin/bash
# list all git repo's in subdirectories, by default listing all
# branches (local and remote).
# Optionally pass in a different git command to run: e.g.,
#   *  branch -v -a  # (default)
#   *  branch        # only local branches
#   *  pull          # pull currently co'd branch
#   *  status        # status for branch


cmd="branch -v -a"
out=index.txt
[ $# -gt 0 ] && cmd="$@" && out=index.$1.txt
[ -f "$out" ] && echo "**warning: file exists: $out" && rm -i "$out"
[ -f "$out" ] && echo "**error: file exists: $out" && exit 2

for x in $( find * -name .git -prune )
do
  d=$(dirname $x)
  echo "========= $d ==============="
  ( cd $d ; git $cmd ; )
done 2>&1 | tee $out | more

printf "\n\n==========\nSaved results to: $out\n"

