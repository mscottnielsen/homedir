#!/bin/bash

usage() { cat<<EOF
  Usage: ${PROG_NAME} [-n|-l|-a|-o] [view...] [-latest|-tip|{label}]
  Refresh the given view, giving either a full view name or pattern.
    view - view name
    -a   - update (refresh) all views (no view name should be given)
    -l   - lists matching views (does not update views)
    -n   - no operation (dry-run), just prints commands

  Advanced:
    -latest|-tip|{label} - passed to ade exec; by default,
         infer refresh to "latest" or "tip" based on view name
EOF
  return 0
}

# Examples:
#   Given:  -n '.*main_latest'
#    lists views suffixed by "main_latest" (but don't refresh)
#    Could also just use "main_latest".
#
#   Given:  'adp.*main'
#     Refresh matching views. Might also use "adp*main". Use view name
#     suffix to decide if view should updated to '-tip' or '-latest'.
#     Otherwise, first try '-tip', then '-latest'.
#     $ ade useview ade_main_tip    -exec "ade refreshview"
#     $ ade useview ade_main_latest -exec "ade refreshview -latest"

PROG_PATH=${BASH_SOURCE[0]}  # this script path, name, & directory
PROG_NAME=${PROG_PATH##*/}
PROG_DIR=$(cd "$(dirname "${PROG_PATH:-$PWD}")" 2>/dev/null 1>&2 && pwd)

#RUN=echo
RUN=

: ${TMPDIR:="/tmp"}
tmpout=$TMPDIR/log_${LOGNAME}_${PROG_NAME}.$$.tmp
trap "rm -f $tmpout >/dev/null 2>&1" 0
trap "exit 2" 1 2 3 15

#######################################################################
tstamp() { date '+%F %X' ; }

#######################################################################
match_view() {
  local view_pat="$1"
  cut -f1 -d\| | sed 's/  *//g' | egrep "^${view_pat}|$(whoami)_.*${view_pat}"
  return $?
}

#######################################################################
## return 0 (true) if no error, else non-zero (false)
check_is_error() {
  grep 'ERROR: ' $tmpout >/dev/null
  [ $? -eq 0 ] && res=1 || res=0

  [ $res -eq 0 ] \
     && cat $tmpout | sed -n '/View/,$p' \
     || cat $tmpout | tail -2

  test $res -eq 0 \
     && echo "##==[$(tstamp)]== refresh success" \
     || echo "##==[$(tstamp)]== refresh failed"

  return $res
}


#######################################################################
## List ade views, optionally grep for a view by view name.
lsviews_ftn() {
  local ret=0 view_pat="$1"
  if [ "$view_pat" != "" ];  then
    ade lsviews | match_view "$view_pat"
    ret=$?
  else
    ade lsviews | match_view .
    ret=${PIPESTATUS[0]} # return result of ade command
  fi
  return $ret
}

#######################################################################
## By default refresh assuming "-tip-default"; or give "-latest"
## or a label. Ignores views currently in a transaction.
## Usage:  do_ade_refresh {view}  [-latest | -tip | {label}]
do_ade_refresh() {
  local view opt
  view=$1; shift
  opt="$@"

  printf "## refresh view=\"$view\"; options ($#): ${opt}\n"
  ade lsviews | egrep "^${view} " | egrep "NONE$" 2>/dev/null || {
    printf "## view in transaction, not updating: ${view}\n"
    return 0
  }

  printf "\n##==[$(tstamp)]== run: ade useview $view -exec \"ade refreshview $opt\"\n"
  $RUN ade useview $view -exec "ade refreshview $opt" 2>&1 | egrep -v '^ *$' > $tmpout
  check_is_error
}

#######################################################################
## Determine full view name and refresh options, then call "do_ade_refresh";
## Args and options can be in any order.
## Usage: refreshview_ftn {view} [-latest|-tip]... [{view} [-latest|-tip]...]
refreshview_ftn() {
  [ $# -eq 0 ] && return 0
  local arg all_args next_option
  local refresh_to="" next_index=0
  local match_tip="[-_]tip$|[-_]tip[-_]"
  local match_latest="[-_]latest$|[-_]latest[-_]"

  all_args=("$@")

  for arg; do
    (( next_index++ ))
    # skip all options, only process view names
    [ "{$arg:0:1}" = "-" ] && continue

    # if *this* is view name, see if *next* is an option (like "-latest")
    next_option=${all_args[$next_index]}
    [ "{$next_option:0:1}" = "-" ] && refresh_to=$next_option

    for view in $(lsviews_ftn "$arg") ; do
       printf "##== view: \"$view\" == "
       if [ "$refresh_to" != "" ] ; then
          do_ade_refresh "$view" $refresh_to
       elif echo "$view" | egrep -q -- "$match_tip" ; then
          do_ade_refresh "$view" -tip
       elif echo "$view" | egrep -q -- "$match_latest" ; then
          do_ade_refresh "$view" -latest
       else
          printf "## attempting default refresh...\n"
          if ! do_ade_refresh "$view" ; then
            printf "\n## refresh view: second attempt, refresh to 'latest'\n"
            do_ade_refresh "$view" -latest  && printf '===OK===\n' || printf '===ERROR===\n'
          fi
       fi
    done || printf "\n** Error refreshing view: \"${view}\"\n\n"
  done
}


#######################################################################
## attempt default refresh, if that fails, attempt to refresh to "-latest"
do_try_refresh() {
  do_ade_refresh $@ || {
    printf "** trying again, using \"-latest\"...\n\n"
    do_ade_refresh $@ "-latest"
  }
}

#######################################################################
## List/refresh views matching pattern
refresh_or_list_views () {
  local opt OPTIND OPTARG
  local ret=0 do_lsviews=false
  while getopts lno opt; do
    case "$opt" in
      l) do_lsviews=true ;;
      n) RUN=echo ;;
      h|*) usage; return 2 ;;
    esac
  done; shift $((OPTIND-1)); OPTIND=1

  if $do_lsviews ; then
    echo "## list views: $@"
    lsviews_ftn "$@"
    ret=$?
  elif [ $# -eq 0 ] ; then
    usage
    return 1
  else
    refreshview_ftn "$@"
    ret=$?
  fi
  return $ret
}

#######################################################################
# main
#######################################################################
refresh_or_list_views "$@"

