#!/bin/bash

usage() { cat<<EOF
  Usage: ${PROG_NAME} [-n|-l|-a|-o] [view...] [-latest|-tip|{label}]
  Refresh the given view, giving either a full view name or pattern.
    view - view name
    -a   - update (refresh) all views (no view name should be given)
    -f   - update the view, even if the label is broken (-force_broken)
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
VERBOSE=false

: ${TMPDIR:="/tmp"}
tmpout=$TMPDIR/log_${LOGNAME}_${PROG_NAME}.$$.tmp
trap "rm -f $tmpout >/dev/null 2>&1" 0
trap "exit 2" 1 2 3 15

#######################################################################
tstamp() {
  date '+%Y-%m-%d-%H:%M:%S' # => 2014-09-07-19:49:29
  # date '+%Y-%b-%d' # => 2014-Sep-07
  # date '+%F %X'    # => 2014-09-07 07:41:17 PM
  # date '+%Y%m%d'   # => sortable YYYYMMDD (20120630),
}

# print msg to stdout
info() {
  local pref="" n='\n'
  [ "$1" = "-t" ] && shift && pref="[$(tstamp)]"   #  -t  include timestamp
  [ "$1" = "-n" ] && shift && n=""                 #  -n  skip newline
  printf "${pref} $@${n}" | sed 's/^/## /'
  return 0
}

warn() {
  info "warning: $@" 1>&2
  return 0
}

#######################################################################
match_view() {
  local view_pat="$1"
  cut -f1 -d\| | sed 's/  *//g' | egrep "^${view_pat}|$(whoami)_.*${view_pat}"
  return $?
}

#######################################################################
## show views updated; if errors, report && return false (ignore warnings)
check_is_error() {
  [ ! -f "$tmpout" ] && { info "refresh status unknown (no output)"; return 0; }
  if egrep 'ERROR: ' "$tmpout" >/dev/null  #  check only for ERRORS (there are ALWAYS warnings)
  then
    cat "$tmpout" | tail -2
    warn "refresh failed\n"
    return 1
  else
    cat "$tmpout" | sed -n '/View/,$p'
    #info "refresh success\n"
    return 0
  fi
}

#######################################################################
## Refresh to "-latest" or a label; by default assumes "-tip-default".
## Ignore views in a transaction, which can't be refreshed anyway.
## Usage:  do_ade_refresh {view}  [-latest | -tip | {label}]
do_ade_refresh() {
  local view=$1
  shift
  local opt="$@"
  $VERBOSE && info "run: ade refreshview \"$view\" ${opt}"
  ade lsviews | egrep "^${view} " | egrep "NONE$" 2>/dev/null || {
    warn "transaction open, not updating view: ${view}"
    return 0
  }
  $VERBOSE && info "ade useview $view -exec \"ade refreshview $opt\""
  $RUN  ade useview $view -exec  "ade refreshview $opt" 2>&1 | egrep -v '^ *$' | tee "$tmpout" | egrep 'WARN|ERROR|ADE_' 1>&2
  check_is_error
}

#######################################################################
## List ade views, optionally grep for a view by view name.
run_lsviews() {
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
## Determine full view name and refresh options, then call "do_ade_refresh".
## Args and options can be in any order.
## Usage: run_refreshview {view} [-latest|-tip]... [{view} [-latest|-tip]...]
run_refreshview() {
  [ $# -eq 0 ] && return 0
  local arg all_args next_option
  local refresh_to="" next_index=0
  local match_tip="[-_]tip$|[-_]tip[-_]"
  local match_latest="[-_]latest$|[-_]latest[-_]"
  local opts="-force_broken"  # now enabled by default; otherwise, refresh hangs

  [ $# -gt 0 -a "$1" = "-f" ] && opts="-force_broken" && shift
  all_args=("$@")

  for arg; do
    (( next_index++ ))
    [ "{$arg:0:1}" = "-" ] && continue   # skip options, only process view names

    # if this is a view name, see if next arg is option (like "-latest")
    next_option=${all_args[$next_index]}
    [ "{$next_option:0:1}" = "-" ] && refresh_to=$next_option

    for view in $(run_lsviews "$arg") ; do
       echo
       info "refreshing view \"$view\"..."
       if [ "$refresh_to" != "" ] ; then
          do_ade_refresh "$view" $refresh_to $opts
       elif echo "$view" | egrep -q -- "$match_tip" ; then
          do_ade_refresh "$view" -tip $opts
       elif echo "$view" | egrep -q -- "$match_latest" ; then
          do_ade_refresh "$view" -latest $opts
       else
          info "attempting default view refresh..."
          if ! do_ade_refresh "$view" $opts; then
            info "...(second attempt) refreshing view, to 'latest'"
            do_ade_refresh "$view" -latest $opts
          fi
       fi
    done || printf "\n## error: unable to refresh view \"${view}\"\n\n"
  done
}

#######################################################################
## List/refresh views matching pattern
refresh_or_list_views () {
  local ret=0 do_lsviews=false opts="" opt="" OPTIND OPTARG
  while getopts flno opt; do
    case "$opt" in
      l) do_lsviews=true ;;
      n) RUN=echo ;;
      f) opts="-f" ;;
      v) VERBOSE=true;;  # technically, can't pass this from lsview
      h|*) usage; return 2 ;;
    esac
  done; shift $((OPTIND-1)); OPTIND=1

  if $do_lsviews ; then
    info "list views: $@"
    run_lsviews "$@"
    ret=$?
  elif [ $# -eq 0 ] ; then
    usage
    return 1
  else
    run_refreshview $opts "$@"
    ret=$?
  fi
  return $ret
}

refresh_or_list_views "$@"

