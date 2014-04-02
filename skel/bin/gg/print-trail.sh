#!/bin/bash
##
## Dump a trail to stdout via logdump.
## Allow multiple trails to be passed in, or just a trail prefix. Any logdump
## commands can be specified as command line arguments (including filters), e.g.,
##  print_trail.sh "ghdr on" "ggstoken detail" dirdat/aa
##
#############################################################################

#############################################################################
usage() { cat <<EOF
 Usage: ${BASH_SOURCE[0]##*/} [-N {num}] ["logdump option_1" "option_2" ...] trails...

 Run logdump on the given trail(s), printing the entire trail to stdout.
 Use "-N" to limit the number of records printed. Multiple logdump options
 can be given on the command line (using quotes), e.g.,
   ${BASH_SOURCE[0]##*/} "count detail" "ggstoken detail" dirdat/aa

 Options:
   -d     - prints data (column) detail (plus file headers and token detail)
   -h     - print help
   -N num - limit records displayed per trail to {num}
   -p pos - start at given position in the given trail
   -t     - all token details (usertoken, ggstoken, headertoken)
   -T     - don't print tokens
   -v     - verbose, print detailed count, headers, tokens, data

 Advanced:
   -D  - print logdump commands only, to be used as input to logdump. Does use
         logdump to get the record count, unless explicitly given (using "-N")

 Assumes 'logdump' can be found in the current directory or parent directory
 (i.e, if run from inside dirdat). Alternatively, set LOGDUMP="path/to/logdump"

 The default options are:
   $(for x in "${opts[@]}"; do printf "  \"$x\"" ; done)

EOF
 return 0
}

#############################################################################
usage_exit() {
  usage
  exit $1
}


#############################################################################
#  Notes:
#  The shortest way (linux) to print {num} records:
#    $ num=100
#    $ yes next | head -${num} | ./logdump open trail
#
#  To set logdump options:
#    $ ( printf "ggstoken detail\n"; yes next | head -${num} ) | ./logdump open dirdat/tc000000
#    $ ( printf "ggstoken detail\n usertoken detail\n"; ... etc...
#
#  To process multiple trails:
#  $ for t in dirdat/aa*
#    do
#      ( printf "ggstoken detail\n usertoken detail\n detail data\n"; yes next | head -100 ) | ./logdump open $t
#   done | egrep "some pattern"
#
#  If not linux, "yes" may not exist (it repeatedly prints the given string).
#  Logdump prints its prompt unnecessarily when reading via stdin; an upper bound
#  is therefore required on 'yes' via 'head'. This script uses logdump to calculate
#  the exact record count if no limit is given; also all the extra "logdump" prompts
#  are cleaned up as well.


#############################################################################
# script name, directory, etc
prog=${BASH_SOURCE[0]}
progname=${BASH_SOURCE[0]##*/}
progdir=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)

# run logdump from gg_home OR from dirdat; if dirdat is symlink, use abs path to logdump
: ${LOGDUMP:="./logdump"}
[ ! -e "$LOGDUMP" ] && [ -e $(dirname $PWD)/logdump ] && LOGDUMP=$(dirname $PWD)/logdump

# use GNU awk and GNU sed, if possible (esp. on Solaris)
type gawk > /dev/null 2>&1 && AWK=gawk || AWK=awk
type gsed > /dev/null 2>&1 && SED=gsed || SED=sed

declare -a trails opts
max_num=
start_pos=

#############################################################################
## default options
opts=(
  "ghdr on"
  "usertoken detail"
  "ggstoken detail"
  "fileheader detail"
)

#############################################################################
## dump trail to stdout, also clean up extra 'Lodgump>' prompts, fix newlines
dump_trail () {
  [ "$commands_only" = "" ] \
    && $LOGDUMP OPEN $1 | $SED 's/^Logdump.*Logdump.*Logdump.*> *//; s/Logdump .*>/&\n/' \
    ||  { printf "OPEN $1\n"; cat; }
}


#############################################################################
## process commandline options, allowing any logdump commands to also be given
OPTIND=1
while getopts dDhN:p:tv opt ; do
  case "$opt" in
    d) opts=( "ghdr on" "usertoken detail" "ggstoken detail" "headertoken detail" "fileheader detail" "detail data" ) ;;
    D) commands_only=true ;;
    h) usage_exit 1 ;;
    N) max_num=${OPTARG} ;;
    p) start_pos=${OPTARG} ;;
    t) opts=( "ghdr on" "usertoken detail" "ggstoken detail" "headertoken detail" "fileheader detail" ) ;;
    T) opts=( "ghdr on" ) ;;
    v) opts=( "ghdr on" "usertoken detail" "ggstoken detail" "headertoken detail" "fileheader detail" "detail data" "count detail" ) ;;
    *) usage_exit 2 ;;
  esac
done; shift $((OPTIND-1)); OPTIND=1

[ $# -eq 0 ] && usage_exit 2

[ "$start_pos" != "" ] && opts=( "${opts[@]}" "pos ${start_pos}" )

#############################################################################
## if not a file OR a two-letter trail prefix, assume command line argument
## is a logdump option, and pass it straight though to logdump (e.g., "detail data" "show env")
for arg ; do
  if [ -e "$arg" ]; then
    trails=( "${trails[@]}" "$arg" )
  else
    # check for two-character trail name
    prefix=${arg##*/}  # same as basename
    if [ ${#prefix} -eq 2 -a -d $(dirname -- "$arg") ] ; then
      #for f in ${arg}?????? ; do
      for f in ${arg}[0-9][0-9][0-9][0-9][0-9][0-9] ; do
        [ -e "$f" ] && trails=( "${trails[@]}" "$f" )
      done
    else
      opts=( "${opts[@]}" "${arg}" )
    fi
  fi
done

#############################################################################
## For each trail, dump text to stdout via logdump. First, pass in logdump
## options to control filtering, positioning, verbosity, etc.
for trail in "${trails[@]}" ; do
  [ ! -e "$trail" ] && echo "** warning: file not found: $trail" 1>&2 && continue

  # optionally limit recs to "max_num"; print all by default (may not work so well if filtering)
  [ "$max_num" != "" ] \
      && num=$max_num \
      || num=$(echo 'count' | $LOGDUMP OPEN $trail | awk '/has.*records/ { print $(NF-1) }')

  # only print the logdump commands to stdout (can feed this to logdump manually)
  [ "$commands_only" = "" ] && printf "trail $trail => print $num records\n"

  # pipe commands into logdump, filtering output
  ( x=1
    printf "$(printf "%s" "${opts[@]/%/\n}")"
    while (( x++ <= num ))
    do
      printf "next\n"
    done ) | dump_trail $trail
done

