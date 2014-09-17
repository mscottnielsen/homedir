#!/bin/bash
#
# Apply a patch file to git.
#
# To update files in git (if ADE files are newer), assuming the patch file for
# git was created (patch__OLD.git...NEW.ade), apply using:
#  $ cd patch/oggadp_main/ade/oggadp
#  $ patch [ --dry-run ] -p1 < ../../../../patch__OLD_oggadp.git__NEW_{...}
#
# Notes:
#  Patch-files are generated from the diff-patch script, which compares the
#  files in ADE with the corresponding 'git' branch.
#
#

prog=${BASH_SOURCE[0]}

usage() { cat<<EOF
   Apply patch file to git.
   Usage: ${prog} [-b {source}] [-n] [-h] patch_file
     -b {Adp_binary_source_dir}  generate script to copy binary files to target
     -h   print usage
     -n   dry-run
EOF
  return 0
}

#########################################################################
# Print given error message, and exit
# Usage: die [-u] [message]
#   -u  - print usage, otherwise just print error (if any) and exit
die() {
  local do_usage=false
  [ "$1" = "-u" ] && do_usage=true && shift
  [ $# -gt 0 ] && printf "** Error: $@\n\n" 1>&2
  $do_usage && usage
  exit 2
}

#########################################################################
# generate a script to copy binary files from source to target
binary_update() {
  local base="Adp__msnielse_oggadp_main_dev_adc6140259_20131117_tip__2013.11.17.22.47"

  diff -q -r $base/QA/ oggadp_main/ade/oggadp/QA/ \
     | awk '{ print $3 $4 }' \
     | awk -F: '{ print $1 "/" $2 " " $1 }'  \
     | sed "s/ ${base}\/*/  oggadp_main\/ade\/oggadp\//" \
     | sed 's/^/cp -ir /' \
     | egrep -vi 'zip |jar ' \
     | egrep -v '/libs/|/ant-latest|/jdbc|\.settings|/executables'

    # Binary:
    #  diff -q -r Adp__msnielse_*/QA/ oggadp_main/ade/oggadp/QA/ \
    #     | awk '{ print $3 $4 }' \
    #     | awk -F: '{ print $1 "/" $2 " " $1 }'  \
    #     | sed 's/ Adp__msnielse_oggadp_main_dev_adc6140259_20131117_tip__2013.11.17.22.47./  oggadp_main\/ade\/oggadp\//' \
    #     | sed 's/^/cp -ir /' \
    #     | egrep -vi 'zip |jar ' \
    #     | egrep -v '/libs/|/ant-latest|/jdbc|\.settings|/executables'
}

#########################################################################
# Ask y/n and return true/false. If given "q", exits the script.
# If assume_yes=true, return true, no user input required.
# Example: ask "run build?" && make all || echo "bye"
#
ask() {
  $assume_yes && return 0
  local yn=y
  echo "# == (verify):  $@"
  read -n1 -p "# == continue? [y|n|q] (y)" yn
  [ "$yn" = "q" ]  && printf "  ([$yn]...exiting...)\n" && exit 1
  [ "$yn" = "" -o "$yn" = "y" ] && printf "\n" && return 0
  printf "  ([$yn]...skip & continue...)\n"
  return 1
}

do_patch() {
  local patch_file=$1
  [ $# -eq 0 -o "$patch_file" = "" ] && echo "** expecting patch file (${patch_file})" && usage && return 2
  [ ! -f "$patch_file" ] && echo "** file not found: $patch_file" && return 2
  ( cd oggadp_main/ade/oggadp \
       && [ -f   ../../../$patch_file ] \
       && echo "run: patch $PATCH_OPTS -p1 < ../../../$patch_file" \
       && patch $PATCH_OPTS -p1 < ../../../$patch_file  \
       && { echo "** success: applied patch." ; return 0 ; } \
       || { echo "** error: unable to apply patch: $patch_file"; return 1; }  )
}

echo "===$@"

OPTIND=1
while getopts b:hn opt ; do
  case "$opt" in
  h) die -u
     ;;
  n) dry_run=true
     PATCH_OPTS="$PATCH_OPTS --dry-run"
     ;;
  b) binary_update $OPTARG
     exit
     ;;
  *) die -u "unknown option: $@\n\n"
     ;;
  esac
done; shift $((OPTIND-1)); OPTIND=1

do_patch $@


