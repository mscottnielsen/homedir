#!/bin/bash
#
# Strip timestamps from text, converting {date}-{time} to a constant
# string => {2000-01-01} {33:33:33}
#
# Can be used as a pipe, or with file argument(s). If given files, a
# new file is created with suffix ".2" (by default).
#
# The actual separator is preserved in the timestamp (":", vs. "_", etc).
# since that may be an important difference (testing date formatting).
#
# Options:
#    -i {suffix}  - if given {file} as an argument, write
#                   output to {file}.{suffix} (default suffix='2')
#    -n           - strip line numbers (debug logfile)  (foo.c:1234 => foo.c:0000)
#
# Examples:
#   orig: 2012-07-18 08:04:43   ... 2012-07-18_08-04-37_0000000000_ ....
#   new:  2000-01-01 33:33:33   ... 2000-01-01_33-33-33_0000000000_ ....
#############################################################################

sufx="2"
stdout=true
do_strip_lineno=false

#############################################################################
# strip line numbers from filename: foo.c:23 => foo.c:000
#
strip_lineno() {
  local line='s/\(^[a-zA-Z0-9_]\.[Cch][Cchp]*\):[0-9][0-9]*)/\1:000)/g'
  $do_strip_lineno && sed "$line" $@ || cat $@
}

#############################################################################
# strip dates/timestamps
#
strip_timestamps() {
  local default_pat='s/20[012][0-9]\(.\)[01][0-9]\(.\)[0123][0-9]\(.\)[012][0-9]\(.\)[0-9][0-9]\(.\)[0-9][0-9]/2000\101\201\333\433\533/g'
  sed "$default_pat" $@ | strip_lineno
}

#############################################################################
# if a file isn't removed gracefully, then exit
#
try_delete() {
  [ -f ${1} ] && rm -i ${1}
  [ -f ${1} ] && return 1 || return 0
}

#############################################################################
# main
#############################################################################
OPTIND=1

while getopts i:n  opt; do
  case "$opt" in
    i) sufx=${OPTARG}
       stdout=false ;;
    n) do_strip_lineno=true ;;
    *) printf "\n Usage: $(basename $0) [-i sufx|-n] [file...]\n\n" && exit 2 ;;
  esac
done; shift $((OPTIND-1)); OPTIND=1


if [ $# -eq 0 ]; then
   strip_timestamps
else
  for f ;  do
    if $stdout ; then
      strip_timestamps ${f}
    else
      try_delete ${f}.${sufx} && strip_timestamps ${f} > ${f}.${sufx}
    fi
  done
fi

