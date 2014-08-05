#!/bin/bash
#
# Usage: ade-lsview.sh [options] [pattern]
# List ADE views that either:
#   (1) match a pattern, either a regexp (foo.*[0-9]) or simple glob (foo*99));
#   (2) OR, have open transactions;
#   (3) OR, are out-of-date and require 'ade refresh'
#
#  The matching view(s) may be:
#   (1) simply listed (optionally, using the "long" listing),
#   (2) "used" (entered into, using "ade useview")
#   (3) destroyed,
#   (4) refreshed,
#   (5) used to create a duplicate view (new name, same label/series)
#
# Options (run with '-h' to see all options):
#   -h   print usage
#   -l   long listing (if selected, used for pattern match)
#   -o   list out of date views
#   -t   list views with open transactions
#   -r   refresh matching views
#   -u   use the (single) matching view; may be used with options: -r, -t, -o, -l
#   -c   create new view w/ same specs; additional args used for new view name.
#
# Examples:
#   Listing views, using views, refreshing views:
#   $ lsview core*11.2            # list views matching regex: ".*core.*11.2.*"
#   $ lsview -l adp*11.2*bug123   # long listing for matching views (shows txns)
#   $ lsview -r 'oggcore*'        # refresh all matching views
#
#   $ lsview -u 'core*11.2*test'  # use matching view (only if there is 1 match)
#   $ lsview -u -r core*11.2*test # refresh (-r) matching view, then use it (-u)
#   $ lsview -t -u                # list view with open txn; if one match, use it
#
# Note: This script calls external scripts for some of this functionality.
##############################################################################

_ade_lsview_usage() {
  cat <<USAGE_EOF
  Usage: lsview [grep_opt] [-c -d -h -l -o -r -s -t -u] [pattern]

  List ADE views by pattern using either a regular expression or wildcard, matching
  either just the view name (default), or the ADE view 'long' listing (-l). Optionally
  lists views with an open transaction (-t) or out-of-date (-o) views, which can then
  be refreshed, 'used', or deleted.
  Note: external scripts are called for some actions, and view names are expected to
  be formatted as: {user}_{series}_[host_][date_][desc_]{tip|latest|label}

  Examples:
    $ lsview 'oggcore*20140602'
        mnielsen_oggcore_main_adc987654_20140602_perftest_latest
        mnielsen_oggcore_11_2_1_slc123456_20140602_bug_123456_tip
    $ lsview -r 'oggcore*20140602'
        ...refreshing (2) matching views... (etc)
    $ lsview -r -u 'oggcore*bug*tip'
        ...refreshing (1) matching views...
        ...entering view: mnielsen_oggcore_11_2_1_slc123456_20140602_bug_123456_tip

  Options/arguments:
    {pattern}   - regexp/wildcard for view name/desc ('^foo.*[0-9].*bar' or 'foo*bar')
    [grep_opt]  - grep option: {-i -v -q -n -w -Z --color=[never|always|auto]}
    -h          - print usage message
    -l          - long listing of matching views
    -y          - assume "yes" to some questions (eg, "destroy view? [y/n]")

  Selecting:
    -o   - matches out-of-date views, requiring refresh
    -t   - matches views with an open transaction

  Actions:
    -c   - create a new view, similar to the matching view. Argument
           is used to create new view name, eg: lsview -c {pattern} {desc}
    -d   - destroy matching view(s)
    -r   - refresh the matching views, eg: lsview 'dev[0-9].*tip' or '*latest'
    -u   - use the matching view (if a single view matches)

USAGE_EOF
}

PROG_PATH=${BASH_SOURCE[0]}      # this script's name
PROG_NAME=${PROG_PATH##*/}       # basename of script (strip path)
PROG_DIR="$(cd "$(dirname "${PROG_PATH:-$PWD}")" 2>/dev/null 1>&2 && pwd)"
: ${ADE_REFRESH_SCRIPT:="$PROG_DIR/ade-refresh-view.sh"}

# either run ade directly; or, allow just printing out the command that would be run (debug)
: ${ADE_EXE:="ade"}
#DO_RUN=echo
ADE_PROG="$DO_RUN $ADE_EXE"

##############################################################################
_ade_lsview_ask() {
  # Ask "are you sure [y|n]", return true(0) or false(1,2)
  # Usage: ask [-q] "question..." && continue || exit
  #   -q   add option "q(uit)" returning false (2)
  local yn='n' allow_quit=false opts='[y|n]'

  [ "$1" = "-q" ] && shift && allow_quit=true && opts='[y|n|q]'
  read -n 1 -s -p "$@ $opts (default=n) " yn

  [ "$yn" = "y" ] \
      && printf " [answer=$yn => yes]\n" 1>&2 \
      && return 0

  $allow_quit && [ "$yn" = "q" ] \
      && printf " [answer=$yn => QUIT]\n" 1>&2 \
      && return 2

  printf "\n" 1>&2
  return 1
}

##############################################################################
# usage: _ade_lsview_get_view_name [-l|-n] [views]
_ade_lsview_get_view_name() {
  # Convert input "view1,view2,view3" to one view per line. Also works in a pipe.
  # If working with 'long' listings, the input is trimmed, returning only view name),
  # one per line. If given (-l) return all original args (keep "long" view listing).
  # If given '-n', just return number of views.
  local format_output=trunc
  [ $# -gt 0 -a "$1" = "-l" ] && format_output=cat && shift
  [ $# -gt 0 -a "$1" = "-n" ] && format_output=word_count && shift

  # truncate output after "|"
  trunc() { cut -d\| -f1 | sed 's/  *//g' ; return 0; }

  # just count lines
  word_count() { grep '.' |  wc -l; return 0; }

  # convert a,b,c => one per line
  parse_input() { tr ',' '\n' ; return 0; }

  if [ $# -gt 0 ]; then
    echo "$@" | parse_input | $format_output
  else
    parse_input | $format_output
  fi
  return 0
}

##############################################################################
_ade_lsview_grep() {
  # Filter "ade lsviews" output
  # Usage: _ade_lsview_grep [ -l -t -s ] {pattern} {grep_opts}
  #   {pattern}  - optional reg exp, show views matching the pattern
  #   {grep_opts} - any valid grep option(s)
  #   -l    -  long ade lsviews listing
  #   -t    -  list only views with open txn
  #   -s    -  print only matching view series names

  local only_tx=false  out_of_date=false get_series=false long_opt="" pattern="" grep_opts="" opt="" lsview_opt=""
  local opt OPTIND OPTARG
  local args="$@"

  while getopts hlost opt ; do
    case "$opt" in
      h) printf "** usage: [-l -o -s -t -h] pattern [grep-opts]\n" 1>&2
         ;;
      l) long_opt="-l"
         ;;
      o) out_of_date=true
         lsview_opt="-label_status"
         ;;
      s) get_series=true
         long_opt="-l"
         ;;
      t) only_tx=true
         ;;
      *) printf "** Usage: [-c -d -h -l -o -r -s -t -u] pattern [grep-opts]\n" 1>&2
         printf "** Error: unknown option ($args). Use '-h' (help) option for more information.\n" 1>&2
         return 2
         ;;
    esac
  done; shift $((OPTIND-1)); OPTIND=1

  [ $# -gt 0 ] && pattern=$1 && shift
  [ $# -gt 0 ] && grep_opts="$@"

  filter_tx() {  # only show views with open txn
    if $only_tx ; then
       egrep -v 'NONE *$'
    elif $out_of_date ; then
      egrep 'NOT AVAILABLE'
    else
       cat
    fi
  }

  filter_view_name() {  # view name only, UNLESS long listing OR list txn's
    if $only_tx || $out_of_date ; then
      _ade_lsview_get_view_name -l
    else
      _ade_lsview_get_view_name $long_opt
    fi
  }

  print_results() {
    if $get_series ; then
       cut -d\| -f2 | sed -e 's/^ *//; s/ *$//' -e 's/\.[0-9]\{4\}$//' -e 's/_*[0-9]\{6\}$//' # | sort -u
    else
       cat
    fi
  }

  $ADE_EXE lsviews $lsview_opt \
      | filter_view_name | sort \
      | egrep $grep_opts "${pattern:-".*"}" \
      | filter_tx \
      | _ade_lsview_get_view_name $long_opt \
      | print_results
}


##############################################################################
_ade_lsview_to_lower() {
  do_sed () { sed -e 's/\(.*\)/\L\1/; s/-/_/g' ; }
  if [ $# -gt 0 ] ; then
     printf "$@" | do_sed
     return 0
  else
     do_sed
     return 0
  fi
}


###############################################################################
_ade_lsview_create_similar_view() {
  # Given an existing view, create a new view (similar name, with updated date
  # timestamp), with the same options. Determine
  #   (1) "-latest" or "-tip_default" from view name,
  #   (2) series from long listing of existing view
  # Additional 'ade createview' command line options are passed through to the
  # ade command ("ade createview"). The new view name includes a date, and
  # optional any additional given description.
  #
  # Usage: {view_name} ["optional desc"] [-optional_args]
  #
  local desc opts new_view_name new_view_type new_view_series
  local print_name_only=false
  [ "${1}" = "-n" ] && print_name_only=true && shift

  local orig_view_name="$1"
  shift

  [ "${1:0:1}" != "-" ] && desc=$1 && shift
  opts=$@
  [ "$opts" = "" ] \
    && new_view_type=$(echo "${orig_view_name}" | egrep "[-_]tip" >/dev/null && echo "-tip_default" || echo "-latest")

  get_view_desc() {
    # from view name get desc/comment; remove "_tip", "_latest", date/time, etc
    local oldview=$1
    echo "${1}" | sed -e 's/_*tip.default//g' \
                      -e 's/_*default//g' \
                      -e 's/_tip$//'  \
                      -e 's/_latest$//g'  \
                      -e 's/_label$//' \
                      -e 's/_20[12][0-9]_*[0-9][0-9]_*[0-9][0-9]_*//' \
                      -e 's/--*/_/g'
  }

  new_view_series=$(_ade_lsview_grep -s ${orig_view_name})  # only matching view series names

  # generate new view name: add date, "latest" or "tip" (avoiding duplicate strings)
  if [ "$desc" = "" ]; then
    # if generating new view name based on old, probably already have series/comment; strip all else
    new_view_name=$(get_view_desc "${orig_view_name}")
    new_view_name=$(echo "${new_view_name}${opts}${new_view_type}" \
        | sed -e 's/--*/_/g' \
              -e 's/_default//' \
              -e 's/  *//g' \
              -e "s/_[^_]\{1,\}\$/_$(date '+%Y%m%d')&/g" \
              -e 's/--*/_/g')
  else
    new_view_name=$(echo "${LOGNAME}_${new_view_series}${opts}_${desc}_${new_view_type}" \
        | sed -e 's/_PLATFORMS//' \
              -e 's/_RELEASE//'  \
              -e 's/_default//' \
              -e 's/  */_/g' \
              -e "s/_[^_]\{1,\}\$/_$(date '+%Y%m%d')&/g" \
              -e 's/[-_][-_]*/_/g' \
        | _ade_lsview_to_lower)
  fi

  # if given '-n' option, just print the name of the view that would be created
  $print_name_only && printf "$new_view_name" && return 0

  opts="-series ${new_view_series:-'series_unset'} $new_view_type $opts"

  echo "** creating a new view based on existing view (opts=\"$opts\")"
  echo "** run: ade createview "$new_view_name" $opts"
  _ade_lsview_ask "*** create view? " || { echo "** not creating view"; return 2; }
  $ADE_PROG createview "$new_view_name" $opts
  # return $? # => return status of 'createview'
}

##############################################################################
lsview() {
  # List views matching a pattern (regex or wildcard); calls script to do refresh
  local ls_opt="" arg="" opt="" res=0 ask=true tmp=""
  local grep_opts="" pattern="" extra="" views="" new_view_name="" view_name="" view_count=0
  local list_msg="" do_list=true do_useview=false do_refresh=false do_destroy=false do_create=false
  local script_found=true refresh_script=$ADE_REFRESH_SCRIPT

  split() { # convert "-abc -def" into "-a -b -c -d -e -f"
    local x opt
    for x; do
      opt="$x"
      [ "${x:0:1}" = "-" -a ${#x} -gt 2 ] && opt=$(echo "$x" | sed 's/[a-zA-Z]/ -&/g; s/[- *]* -/ -/g; s/^ *//; s/ *$//')
      printf -- "$opt"
    done
  }

  # instead of using getops, we allow options after args: cmd -a -b arg1 -opt1 -opt2 arg2
  for arg; do
    for opt in $(split $arg) ; do
      case "$opt" in
        -i | -q | -n | -v | -w | -Z | --color*)
            grep_opts="$(echo $grep_opts $opt)"
            ;;
        -c) do_create=true         # create new view, similar matched
            ls_opt="$ls_opt -l"    # long listing of view names
            ;;
        -d) do_destroy=true        # destroy view(s) matching pattern
            ;;
        -h) _ade_lsview_usage
            return 2
            ;;
        -l) ls_opt="$ls_opt -l"    # long listing of view names
            ;;
        -o) ls_opt="$ls_opt -o"     # listing out of date view
            list_msg="$list_msg (out of date)"
            ;;
        -r) do_refresh=true        # refresh view(s) matching pattern
            do_list=false          # but don't list matching views
            ;;
        -t) ls_opt="$ls_opt -t"    # list only views with open txn
            list_msg="$list_msg (w/ open tx)"
            ;;
        -u) do_useview=true        # use the given view, if single match
            do_list=false
            ;;
        -y) ask=false
            ;;
         *) # one pattern, and the rest passed to useview/refreshview
            [ ${#pattern} -eq 0 ] && pattern="$opt" || extra="$extra $opt"
            ;;
      esac
    done
  done

  # allow regexp or wildcard (foo.*bar or foo*bar); convert "*" to ".*"
  echo "$pattern" | egrep '[$\[^]|\.\*' >/dev/null 2>&1 || pattern="${pattern//[* ]/.*}"

  # all matching views, on one line separated by commas
  views=$( _ade_lsview_grep $ls_opt "${pattern}" ${grep_opts} | paste -sd, - )
  view_count=$(_ade_lsview_get_view_name -n "$views")

  [ $view_count -eq 0 ] \
    && printf "# no views matching pattern: pattern=\"${pattern:-"*"}\"${list_msg}\n" 1>&2 \
    || printf "# pattern=\"${pattern:-"*"}\",${list_msg} matching views=$view_count\n" 1>&2

  [ ! -f "$refresh_script" ] && script_found=false \
    && { printf "\n** Warning: script not found: ${refresh_script}\n" 1>&2; }

  $do_refresh && ! $script_found \
    && { printf "** Error: can't refresh views; refresh script not found: ${refresh_script}\n" 1>&2; return 2; }

  $do_create && [ $view_count -gt 1 ] \
    && { printf "** Warning: more than one view matches pattern, can't create duplicate view\n" 1>&2; return 2; }

  $do_useview && [ $view_count -gt 1 ] \
    && { printf "** Warning: more than one view matches pattern, can't run \'ade useview\'\n" 1>&2; return 2; }

  # list view(s)
  if $do_list ; then
    echo "$views" | _ade_lsview_get_view_name -l
    res=$?
  fi

  # create new view, similar to matching view (only if one match)
  if $do_create ; then
    if [ $view_count -gt 1 ] ; then
      printf "** Warning: more than one view matches, not creating a new view\n" 1>&2
      res=3
    elif [ $view_count -eq 1 ] ; then
      view_name=$(_ade_lsview_get_view_name "$views")
      new_view_name=$(_ade_lsview_create_similar_view -n $view_name)
      _ade_lsview_create_similar_view "$view_name" "$extra" || { new_view_name=""; return 2; }
      res=$?
    else
      printf "** no matching view found\n" 1>&2
      res=1
    fi
  fi

  # do refresh view(s) (multiple matches allowed)
  if $do_refresh && $script_found ; then
    [ "$new_view_name" != "" ] && tmp=$new_view_name || tmp=$views
    for v in $(_ade_lsview_get_view_name $tmp);  do
      $DO_RUN $refresh_script "$v" $extra 1>&2 \
         || { printf "\n** Error: can't refresh=\"$v\" options=\"$extra\" script=$refresh_script\n" 1>&2 ; return 2; }
    done
  fi


  # destroy view(s) (multiple matches allowed)
  if $do_destroy ; then
    if [ $view_count -gt 1 ] ; then
      printf "** Warning: more than one view matches pattern ($view_count views)\n" 1>&2
      if $ask ; then
        _ade_lsview_ask "** continue to destroy all matching views? " || return 2
      fi
    fi

    for v in $(_ade_lsview_get_view_name $views);  do
      if $ask ; then
        _ade_lsview_ask "** Warning: destroy view: $v" || return 2
      fi
      echo "ade destroyview -rm_twork -force $v"
      $ADE_PROG destroyview -rm_twork -force $v \
         || { printf "\n** Error: can't destroy view: \"$v\"\n" 1>&2 ; return 2; }
    done
  fi

  # use view (only if one match)
  if $do_useview ; then
    if [ $view_count -gt 1 ] ; then
      printf "** Warning: more than one view matches pattern, not entering view\n" 1>&2
      res=3
    elif [ $view_count -eq 1 ] ; then
     view_name=$(_ade_lsview_get_view_name "$views")
     [ "$new_view_name" != "" ] && view_name=$new_view_name
      printf "** Entering view: $view_name $extra\n" 1>&2
      $ADE_PROG useview "$view_name" $extra  #1>&2
      res=$?
    else
      printf "** no matching view found\n" 1>&2
      res=1
    fi
  fi

  return $res
}

##############################################################################
lsview "$@"

