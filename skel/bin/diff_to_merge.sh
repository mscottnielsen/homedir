#!/bin/bash
#
############################################################################
prog=$(basename $0)
usage() { cat<<USAGE

   Convert diff (-r) output to perform some action: e.g., meld, kdiff3, cp...
  
   For files "only" in one directory or the other, assume "cp" is the action.
   Generates  a script that can be run and/or modified.
  
   Give the file-merge command as an option or via the env var CMD="{mergetool}"
  
   Usage:
     $ $prog [-m]  [-c "{command}"]   {path1}    {path2}
   Or:
     $ CMD="{command}"   $prog [-m]  {path1}   {path2}
  
   Options
      * -m           - pipe the output through "more" (must be first option).
      * -c {command} - used to merge (or overwrite) the files to merge the two 
                       directories; e.g., "cp" (or "cp -ir") or "meld" or "kdiff3".
                       If unset, can default to env var CMD={command}. 
                       Otherwise, default is "diff".
      * -h           - print this usage message

   Examples:
     $ $prog -m  -c "meld"  ../dir1  /path/to/dir2
     $ CMD="cp -i"   $prog    dir1  dir2
  
   Caveats: this is a total hack. Probably it would be better to just run
            "diff -ruN" to create a patch, and simply apply the patch.
            This version does allow a lot of interfactive "are you sure?",
            and you can script a "checkout" of a file before it's updated.

USAGE
return 0
}
############################################################################


############################################################################
# Recursive "diff" ignoring version control dirs.
# Usage: diffr [options...] dir1 dir2
#
# See also: diffi, sdiffi
#
diffr () {
   # other useful options:
   #   --side-by-side
  diff -r \
       --exclude="*~"  \
       --exclude="*#*"  \
       --exclude="CVS"  \
       --exclude=".svn"  \
       --exclude=".git"  \
       "$@"
}

############################################################################
# diff, ignoring version control dirs + whitespace
# E.g., not unlike => alias idiff='diff -E -b -w -B'
#  diff -E (--ignore-tab-expansion)
#       -b (--ignore-space-change)
#       -w (--ignore-all-space)
#       -B (--ignore-blank-lines)
#  Could also:
#      --ignore-file-name-case
#      --ignore-matching-lines="^ *\* *" \  (C/C++ comments begin w/ "*")
#
diffi () {
    diffr \
       --ignore-tab-expansion \
       --ignore-space-change \
       --ignore-all-space \
       --ignore-blank-lines \
       "$@"
}


############################################################################
# Case-insensitive recursive side-by-side diff, ignoring VCS dirs.
# Like sdiff (diff -y [--left-column]), but 'diff' can be recursive
#
sdiffi() {
    diffi -y --left-column "$@"
}





############################################################################
# main diff_to function converting diff output to a script that (interactively)
# makes the two directories the same.
diff_to () {
  local d1="" d2="" cmd="" pager="cat"

  # tee to temp script file that can be edited and run manually
  local tmp_script=/tmp/diff_to.pid$$.tty$(tty|sed 's:[^0-9]*::g').tmp.sh
  [ -f $tmp_script ] && rm -f $tmp_script
  printf "#!/bin/bash\n\n# comare and merge directories\n\n" > $tmp_script

  # give option "-h" for help
  [ $# -ge 1 -a "$1" = "-h" ] && usage && shift && return 0

  # give option "-m" to page results thru "more"
  [ $# -ge 1 -a "$1" = "-m" ] && pager="more" && shift

  # Default command can be given as env var CMD; use "diff" if unset.
  # Can give commandline option to override env var, e.g., "-c meld".
  [ "$CMD" = "" ] && CMD=diff
  [ $# -ge 2 -a "$1" = "-c" ] && cmd="$2" && shift 2
  CMD="${cmd:-$CMD}"

  # remaining args: look for directory1 and directory2, do recursive diff
  [ -e "$1" ] && d1="$1" && shift && echo "# d1=$d1"
  [ -e "$1" ] && d2="$1" && shift && echo "# d2=$d2"

  # for x
  # do
  #   [ "$d2" = "" -a "$d1" != "" ] && [ -e "$x" ] && d2="$x" && echo "# d2=$x"
  #   [ "$d1" = "" -a -e "$x" ] && d1="$x" && echo "# d1=$x"
  # done

  [ "$d1" = "" -o "$d2" = "" -o ! -d "$d1" -o ! -d "$d2" ] && echo "** error: expecting to compare two directories." && usage && return 2

  #########################################################
  # ask yes or no, return true or false
  ask() {
    local yn=y;
    [ $# -eq 0 ] && q="continue? " | q="$@ ";
    read -n1 -p "#   $@  [y|n|q(uit)] (default=n) " yn && printf "\n";
    [ "$yn" = "q" ]  && printf "#   (...exiting...)\n" && exit 1;
    [ "$yn" != "y" ] && printf "#   (...no...)\n" && return 2;
    return 0;
  }

  printf "
##################################################################
cmd=\"$CMD\"\n" | tee -a $tmp_script

  printf '
##################################################################
# verify (yes/no/quit)
ask() {
    local yn=y;
    [ $# -eq 0 ] && q="continue? " | q="$@ ";
    read -n1 -p "#   $@  [y|n|q(uit)] (default=n) " yn && printf "\\n";
    [ "$yn" = "q" ]  && printf "#   (...exiting...)\\n" && exit 1;
    [ "$yn" != "y" ] && printf "#   (...no...)\\n" && return 2;
    return 0;
}\n' >> $tmp_script

  printf '
##################################################################
## allow commands (e.g., checkout file) to be run before updating target
do_update() {
  #echo "# running: ade co $2"
  #ade co $2
  echo "# running: $cmd"
  $cmd $1 $2
  echo
}\n' | tee -a $tmp_script


  #########################################################
  # attempt to totally reformat output,
  #   =from=> Only in {dir}: {file|dir}
  #   =to===> cp -ir {dir1}/{file|dir} {dir2}
  reformat() {
      from="$1"
      to="$2"
      sz=${#from}

      sed 's/^Only in//; s/:/ /; s/  */ /g' \
        | awk -vcmd="$CMD" -vfrom="$from" -vto="$to" -vsz=$sz '{
             sfx=substr($1,sz);
             printf "echo \"### to do:  cp -r %s/%s  %s/%s\"\n", $1, $2, to, sfx;
             printf "ask \"do copy\" && cp -r %s/%s  %s/%s\n\n",   $1, $2, to, sfx;
           }' \
        | sed 's://*:/:g'
  }

  #########################################################
  # output original diff format for files "only in" one directory,
  # plus a reformatted output that prints the copy command
  print_diff() {
    local dir1=$1
    local dir2=$2
    local d1_pat=${dir1//\//.}

    [ "$d1_pat" = "$dir1" ] && d1_pat=$( echo "$dir1" | sed 's/\./\\./g')

    printf "\n##################################################################\n"
    #printf "# Missing files => \n#   only in: $dir1\n#   copy to: $dir2\n\n"

    printf "echo \"### Missing files =>  \"\n"
    printf "echo \"#   only in: $dir1\"\n"
    printf "echo \"#   copy to: $dir2\"\n\n"

    # just a comment, standard "diff" output: Only in {dir}: {file}
    diffr -q $dir1 $dir2  \
        | egrep "^Only in ${d1_pat}" \
        | sed 's/^/#  /'

    # reformat output, from "Only in dir: file" =to=> "cp -ir dir1/file dir2"
    printf "\n#===\n"
    diffr -q $dir1 $dir2  \
        | egrep "^Only in ${d1_pat}" \
        | reformat "$dir1" "$dir2"
  }

  #########################################################
  # do diff
  printf "\n##################################################################\n"| tee -a $tmp_script
  printf "# Compare diffs:\n#  path1=$d1\n#  path2=$d2\n\n" | tee -a $tmp_script

  diffr -q $d1 $d2  \
     | awk -vcmd="$CMD" -vd1="$d1" -vd2="$d2" '$1 ~ /^Files/ {
           printf "echo \"=================================================================\"\n";
           printf "echo \"==== diff:== %s == %s ===\"\n", $2, $4;
           printf "diff %s %s \n", $2, $4;
           printf "echo \"==== doing: %s == %s == %s ===\"\n", cmd, $2, $4;
           printf "ask \"do %s\" && do_update %s %s \n\n\n", cmd, $2, $4 }' \
     | tee -a $tmp_script \
     | egrep -v 'echo .*====' \
     | $pager

  #########################################################
  # do copy for files "Only in {dir}"
  print_diff ${d1} ${d2} | tee -a $tmp_script | $pager
  print_diff ${d2} ${d1} | tee -a $tmp_script | $pager

  chmod a+x $tmp_script

  printf "\n\n### temp script: \n#  $(ls -l $tmp_script)\n\n"
  ask "run script?" && echo "# running $tmp_script" && $tmp_script
  rm -i $tmp_script
  return 0
}


diff_to $@


