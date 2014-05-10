#!/bin/bash
#
# List ADE views matching a pattern, or views with open transactions, or views
# that are out-of-date. The matching view(s) may simply be listed (optionally
# "long" listing), or destroyed, or refreshed, or used (i.e., "ade useview").
#
# Usage: lsview.sh [-l -t -r -u] [pattern]
# (See help usage for all options.)
#
# The pattern may be a wildcard ("foo*bar") or a regex ("foo.*ba[rt]").
# To "use" a view, only one view may be matched. Multiple matching views can be
# refreshed or deleted or listed.  There is also an option to create a new
# view with similar options as the matching view.  This script calls additional
# external scripts for some of this functionality.
#
# Examples: listing views, using views, refreshing views:
#   $ lsview core*11.2             # list views matching regex: ".*core.*11.2.*"
#
#   $ lsview -l adp*11.2*bug123    # match long listing, includes the ade txn
#   $ lsview -u -r core*11.2*test  # refresh the matching view, then use it
#
#   $ lsview -r 'oggcore*'         # refresh all matching views
#
#   Use matching view (only if there is 1 match):
#   $ lsview -u 'oggcore*11.2*test'
#
#   Use matching view (only if there is 1 match), after a refresh:
#   $ lsview -r -u 'adp*11.2*bug123456'
#
#   List views with open txn; if there is one, use it
#   $ lsview -t -u
#
# Notes:
#  Refreshing views calls an external script, ade-refresh-view.sh
#
##############################################################################

PROG_PATH=${BASH_SOURCE[0]}      # this script's name
PROG_NAME=${PROG_PATH##*/}       # basename of script (strip path)
PROG_DIR="$(cd "$(dirname "${PROG_PATH:-$PWD}")" 2>/dev/null 1>&2 && pwd)"

#DO_RUN=echo
ADE_PROG="$DO_RUN ade"

##############################################################################
_lsviews_ask() {
  # Ask "are you sure [y|n]", return true(0) or false(1,2)
  # Usage:  _lsviews_ask [-q] "question..." && continue || exit
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
_get_view_name() {
  # Trim input, returning only view name (default); or, if given
  # option "-l", just return all original args ("long" view listing: "-l").
  # Convert input "view1,view2,view3" to one view per line.
  local format_output=trunc
  [ $# -gt 0 -a "$1" = "-l" ] && format_output=cat && shift

  # truncate output after "|"
  trunc() { cut -d\| -f1 | sed 's/  *//g' ; return 0; }

  # convert a,b,c => one per line
  parse_input() { tr ',' '\n' ; return 0; }


  if [ $# -gt 0 ]; then
    echo "$@" | parse_input | $format_output
  else
    parse_input | $format_output
  fi
  return 0
}

#######################################################################
## print out-of-date views that require refresh
list_out_of_date() {
  $ADE_PROG lsviews -long -label_status | grep 'NOT AVAILABLE' | awk '{ print $1}'
}

##############################################################################
_lsviews_grep() {
  # Filter "ade lsviews" output
  # Usage: _lsviews_grep [ -l -t -s ] {pattern} {grep_opts}
  #   {pattern}  - optional reg exp, show views matching the pattern
  #   {grep_opts} - any valid grep option(s)
  #   -l    -  long ade lsviews listing
  #   -t    -  list only views with open txn
  #   -s    -  print only matching view series names

  local only_tx=false  out_of_date=false get_series=false long_opt="" pattern="" grep_opts="" opt="" lsviews_opt=""
  local opt OPTIND OPTARG

  while getopts hlost opt ; do
    case "$opt" in
      l) long_opt="-l"
         ;;
      o) out_of_date=true
         lsviews_opt="-label_status"
         ;;
      t) only_tx=true
         ;;
      s) get_series=true
         long_opt="-l"
         ;;
      h) printf "** usage: [-l -o -s -t -h] pattern [grep-opts]\n" 1>&2
         ;;
      *) printf "** Error: unknown option (args=$@)\n" 1>&2
         printf "** usage: [-l -o -s -t -h] pattern [grep-opts]\n" 1>&2
         return 2;;
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
      _get_view_name -l
    else
      _get_view_name $long_opt
    fi
  }

  print_results() {
    if $get_series ; then
       cut -d\| -f2 | sed -e 's/^ *//; s/ *$//' -e 's/\.[0-9]\{4\}$//' -e 's/_*[0-9]\{6\}$//' # | sort -u
    else
       cat
    fi
  }

  ade lsviews $lsviews_opt \
      | filter_view_name | sort \
      | egrep $grep_opts "${pattern:-".*"}" \
      | filter_tx \
      | _get_view_name $long_opt \
      | print_results
}


##############################################################################
_to_lower() {
  do_sed () { sed -e 's/\(.*\)/\L\1/; s/-/_/g' ; }
  if [ $# -gt 0 ] ; then
     printf "$@" | do_sed
     return
  else
     do_sed
     return
  fi
}


###############################################################################
_create_similar_view() {
  # Given an existing view, create a new view (similar name, with updated date
  # timestamp), with the same options. Determine
  #   (1) "-latest" or "-tip_default" from view name,
  #   (2) series from long listing of existing view
  # Additional 'ade createview' command line options are passed through to the
  # ade command ("ade createview"). The new view name includes a date, and
  # optional any additional given description.
  #
  # Usage: _create_similar_view {view_name} ["optional desc"] [-optional_args]
  #
  local desc opts new_view_name new_view_type new_view_series
  local orig_view_name="$1"
  shift
  [ "${1:0:1}" != "-" ] && desc=$1 && shift
  opts=$@
  [ "$opts" = "" ] && new_view_type=$(echo "${orig_view_name}" | egrep "[-_]tip" >/dev/null && echo "-tip_default" || echo "-latest")


  # strip view name down to just the description/comment; remove
  # trailing "_tip" or "_latest", date/timestamp, etc
  get_view_desc() {
    local oldview=$1
    echo "${1}" | sed -e 's/_*tip.default//g' \
                      -e 's/_*default//g' \
                      -e 's/_tip$//'  \
                      -e 's/_latest$//g'  \
                      -e 's/_label$//' \
                      -e 's/_20[12][0-9]_*[0-9][0-9]_*[0-9][0-9]_*//' \
                      -e 's/--*/_/g'
  }

  new_view_series=$(_lsviews_grep -s ${orig_view_name})  # print only matching view series names

  # generate new view name: add date, "latest" or "tip" (avoid duplicate strings)
  if [ "$desc" = "" ]; then
    # if genrating new view name based on old: probably already have series/comment; strip all else
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
        | _to_lower)
  fi

  opts="-series ${new_view_series:-'series_unset'} $new_view_type $opts"

  echo "** creating a new view based on existing view (opts=\"$opts\")"
  echo "** run: ade createview "$new_view_name" $opts"
  _lsviews_ask "*** create view? " || { echo "** not creating view"; return 2; }
  $ADE_PROG createview "$new_view_name" $opts
  res=$?
}


##############################################################################
lsviews() {
  # List views matching a pattern, either a regex or wildcard.
  # Calls ade-refresh-view.sh
  local ls_opt="" opt="" res=0 ask=true
  local grep_opts="" pattern="" extra="" views="" view_name=""
  local list_msg=""
  local do_list=true do_useview=false do_refresh=false do_destroy=false do_create=false

  local refresh_script=$PROG_DIR/ade-refresh-view.sh
  local script_found=true

  usage() { cat <<USAGE_EOF
    Usage: lsviews [grep_opt] [-h -d -l ] [pattern]

    List ADE views by pattern, either regex or wildcard. Patterns matched against
    ADE long listing.  Alternatively, lists views with open transactions (-t) or
    views that are out-of-date (-o).  These options can be combined with options
    to refresh/destroy/use the matching view(s).

    Options/arguments:
     {pattern}   - regexp/wildcard for view name/desc ('^foo.*[0-9].*bar' or 'foo*bar')
     [grep_opt]  - grep option: {-i -v -q -n -w -Z --color=[never|always|auto]}
     -h          - print this help
     -l          - long listing of matching views
     -y          - assume "y" (yes) to questions (eg, "destroy view? [y/n] (default=n)")

    Selecting:
     -o      - matches out-of-date views, requiring refresh
     -t      - matches views with an open transaction

    Actions:
     -c      - create new view, similar to matching view
     -r      - refresh the matching views
     -u      - use the matching view (if a single view matches)
     -d      - destroy matching view(s)
USAGE_EOF
  }

  for opt ; do  # instead of getops, allow options after arguments
    case "$opt" in
      -i | -q | -n | -v | -w | -Z | --color*)
          grep_opts="$(echo $grep_opts $opt)"
          ;;
      -c) do_create=true         # create new view, similar matched
          ls_opt="$ls_opt -l"    # long listing of view names
          ;;
      -d) do_destroy=true        # destroy view(s) matching pattern
          ;;
      -h) usage
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
          [ ${#pattern} -eq 0 ] \
            && pattern="$opt" \
            || extra="$extra $opt"
          ;;
    esac
  done

  # allow regexp or wildcard (foo.*bar or foo*bar); convert "*" to ".*"
  echo "$pattern" | egrep '[$\[^]|\.\*' >/dev/null 2>&1 || pattern="${pattern//[* ]/.*}"

  # count number of matching views, given "view1,view2,view3"
  get_view_count() {
    [ $# -eq 0 -o "$1" = "" ] && { echo 0 ; return 0; }
    echo "$@" | tr ',' '\n' | wc -l
    return 0
  }

  # list the views, one view per line (for iterating over the list)
  get_view_list() {
    # paste -sd, | tr ',' '\n'
    local long=false
    [ $# -gt 1 -a "$1" = "-l" ] && long=true && shift
    echo "$views" | tr ',' '\n' | sed 's/ *|.*//'
  }

  # all matching views, on one line separated by commas
  views=$( _lsviews_grep $ls_opt "${pattern}" ${grep_opts} | paste -sd, - )
  views_count=$(get_view_count "$views")


  [ $views_count -eq 0 ] \
    && printf "# no views matching pattern: pattern=\"${pattern:-"*"}\"${list_msg}\n" 1>&2 \
    || printf "# pattern=\"${pattern:-"*"}\",${list_msg} matching views=$views_count\n" 1>&2

  [ ! -f "$refresh_script" ] && { script_found=false; printf "\n** Warning: script not found: ${refresh_script}\n" 1>&2; }

  #echo "==[begin-debug]==============="
  #echo "$views"
  #echo "=============================="
  #get_view_list
  #echo "==[end-debug]================="

  # if refresh view, make sure refresh script found
  $do_refresh && ! $script_found && { printf "** Error: can't refresh views; refresh script not found: ${refresh_script}\n" 1>&2; return 2; }

  # if useview, make sure only one view matches
  $do_useview && [ $views_count -gt 1 ] && { printf "** Warning: more than one view matches pattern, can't run \'ade useview\'\n" 1>&2; return 2; }

  ### do refresh view(s)
  if $do_refresh && $script_found ; then
    for v in $(get_view_list);  do
      $DO_RUN $refresh_script "$v" $extra 1>&2 \
         || { printf "\n** Error: can't refresh=\"$v\" options=\"$extra\" script=$refresh_script\n" 1>&2 ; return 2; }
    done
  fi

  ### list view(s)
  if $do_list ; then
    #get_view_list
    echo "$views" | _get_view_name -l
    res=$?
  fi

  ### create new view, similar to matching view (only if one match)
  if $do_create ; then
    if [ $views_count -gt 1 ] ; then
      printf "** Warning: more than one view matches, not creating a new view\n" 1>&2
      res=3
    elif [ $views_count -eq 1 ] ; then
      _create_similar_view $(_get_view_name "$views") "$extra"
      res=$?
    else
      printf "** no matching view found\n" 1>&2
      res=1
    fi
  fi


  ### destroy view(s)
  if $do_destroy ; then
    if [ $views_count -gt 1 ] ; then
      printf "** Warning: more than one view matches pattern ($views_count views)\n" 1>&2
      if $ask ; then
        _lsviews_ask "** continue to destroy all matching views? " || return 2
      fi
    fi

    for v in $(get_view_list);  do
      if $ask ; then
        _lsviews_ask "** Warning: destroy view: $v" || return 2
      fi
      echo "ade destroyview -rm_twork -force $v"
      $ADE_PROG destroyview -rm_twork -force $v \
         || { printf "\n** Error: can't destroy view: \"$v\"\n" 1>&2 ; return 2; }
    done
  fi

  ### use view (only if one match)
  if $do_useview ; then
    if [ $views_count -gt 1 ] ; then
      printf "** Warning: more than one view matches pattern, not entering view\n" 1>&2
      res=3
    elif [ $views_count -eq 1 ] ; then
      view_name=$(_get_view_name "$views")
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
# can use lsview or lsviews
lsview() {
   lsviews "$@"
}

lsviews "$@"

