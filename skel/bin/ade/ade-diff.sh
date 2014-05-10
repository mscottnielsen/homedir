#!/bin/bash
#####################################################################################
usage() { cat<<EOF
  Usage: ade-diff.sh [diff-options] [--] [files..]

  Diff the given checked-out files against their previous version.
  By default, diff *all* checked-out files. (See: "ade diff -pred")

  Files specified using their full path (eg, the output of "ade lsco")
  or a relative path (eg, use: find . -name "*.h")

  Options can be passed to 'diff' before the files; pass in "--" to
  indicate end of 'diff' options. The default options are:
     $ ade diff -pred -diff_args $default_opts ...

EOF
  return 0
}

#####################################################################################

# default options for ade diff if no others given: unified diff, ignore whitespace
default_opts=' -diff_args "-wBbu" '

# options to pass to ade diff
opts=""

ls_co() {
  ade lsco 2>&1 | grep '^ '
}

do_diff() {
  for f
  do
    printf "\n========= $f ==================\n"
    [ "${opts}" = "" ] \
      && ade diff -pred ${default_opts}  "$f" \
      || ade diff -pred  -diff_args "$opts" "$f"
    echo
  done
}

for arg; do
  [ -e "$arg" ] && break
  [ "$arg" = "--" ] && shift && break
  [ "$arg" = "-h" ] && shift && usage && exit 2
  echo "# ..adding diff option: $arg"
  opts=" $opts $arg "
  shift
done

if [ $# -gt 0 ] ; then
  printf "======= diff: (options: $opts)\n$@\n\n" 1>&2
  do_diff "$@"
else
  printf "======= diff: (options: $opts)\n$(ls_co)\n\n" 1>&2
  do_diff $( ls_co )
fi

