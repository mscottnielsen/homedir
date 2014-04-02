#!/bin/bash
#
# Colorize 'unified diff' output, optionally piping through $PAGER.
# If unset, PAGER will be set to 'less'. Set to "cat" to not page.
#
# Usage:  colorize.sh [-c|-h|-n] [file...]
#
# Options:
#    -c  force 'cat', no 'diff' if two files ($PAGER still used)
#    -n  more newlines in output
#    -h  print 'help'
#
# Examples:
#   $ diff -u foo bar | colorize.sh
#
#   Assume patch is unified diff:
#   $ colorize.sh  patch.diff
#
#   Runs 'diff -u':
#   $ colorize.sh  file1 file2
#
#   Colorize & not diff, given two files:
#   $ colorize.sh -c file1 file2

prog=${BASH_SOURCE[0]##*/}
usage() { cat<<EOF

  Usage: $prog [-c|-h] [patch | file1 file2]

  Colorize 'diff -u' output (must be unified diff).

  Options:
       -h   print help/usage
       -c   do "cat" (not diff) even given two files
       -n   more newlines in output (for readability)

  Examples:
     Piping diff output to this script
     $ diff file1 file2 | $prog

     Colorize a patch (unified diff) file:
     $ $prog patch

     Or, this script will 'diff' two args:
     $ $prog file1 file2

EOF
  return 0
}

pager_env() {
  # usage: eval $( pager_env )
  #   less is more! (if & when possible...)
  #   prints out commands to be eval'd

  type ${PAGER:="less"} >/dev/null 2>&1 \
    || { type less >/dev/null 2>&1 && PAGER=less ; } \
    || { type more >/dev/null 2>&1 && PAGER=more ; } \
    || { type cat >/dev/null 2>&1 && PAGER=cat ; }

  [ "$PAGER" = "less" -a "$LESS" = "" ] && LESS="-ReXF"
  [ "$PAGER" = "less" -a "$LESS" != "" ] && echo "export LESS=\"${LESS}\"; "
  echo "export PAGER=\"${PAGER}\"; "
}


colorize() {
  # usage: diff foo bar | colorize
  # colorize 'diff' output, optionally piping through $PAGER

  local opt OPTIND OPTARG

  eval $( pager_env )   # set pager
  NL=""                 # optional newline's NL="\n"
  cmd=cat               # diff if args=2, else cat & colorize 

  # default colors
  RED=`echo -e '\033[31m'`
  GREEN=`echo -e '\033[32m'`
  BLUE=`echo -e '\033[36m'`
  YELLOW=`echo -e '\033[33m'`
  NORMAL=`echo -e '\033[0m'`
  
  # options would end up being passed to 'cat'
  [ $# -eq 2 -a "${1:0:1}" != "-" ] && cmd='diff -uN'
  
  while getopts chn opt; do
    case "$opt" in
      c) cmd=cat  ;;
      n) NL="\n" ;;
      h) usage ; return 0 ;;
      *) usage ; return 2 ;;
    esac
  done; shift $((OPTIND-1)); OPTIND=1

  $cmd "$@" | sed "s/^@@.*@@/${BLUE}&${NORMAL}/g" \
            | sed "s/^\+[^+].*/${GREEN}&${NORMAL}/g" \
            | sed "s/^\-[^-].*/${RED}&${NORMAL}/g" \
            | sed "s/^\+\+\+/${GREEN}&${NORMAL}/g" \
            | sed "s/^\-\-\-/${RED}&${NORMAL}/g" \
            | sed "s/^diff .*/${NL}${YELLOW}&${NORMAL}/" \
            | $PAGER
}


colorize "$@"


