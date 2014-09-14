#!/bin/bash
#
# Create an ADE view using simpler, abbreviated series/product/version, etc.
#
# Notes:
#   * view names are formatted such that they can be used with other scripts (eg, lsview)
#   * assumes series & versions are logically sortable -- which unfortunately isn't always true.
#     The organization & naming conventions for ADE OGG series/labels is in a constant state of wtflux.
#   * output may be inserted into a script; all output is 'commented' except the ade commands
#   * use "-y" to avoid user-interaction, and/or "-q" to print less info
#   * use "-n" to just print out the view name to create (not the ade command); this can be used
#     to consistently format view names, even if not using the script to create the view.
#
# Example:
#   Create "tip" (-t) view for the most recent series (-s) 12.1.2, on
#   product (-p) OGGCORE, using the description 'qa testing'
#
#      $ ade-create-view.sh -t -s 12.1.2 -p oggcore  qa test
#      ## Search product "OGGCORE" for series "12.1.2"...
#      ## Creating view: msnielse_oggcore_12_1_2_1_0_adc6140259_20140907_qa_test_tip
#      ## Execute:
#      ##    ade createview  -series OGGCORE_12.1.2.1.0_PLATFORMS -tip_default \
#      ##                  msnielse_oggcore_12_1_2_1_0_adc6140259_20140907_qa_test_tip
#      ##  Create the view? [y|n|q] (n) y    (continuing.....)
#      ade createview -series OGGCORE_12.1.2.1.0_PLATFORMS -tip_default \
#                          msnielse_oggcore_12_1_2_1_0_adc6140259_20140907_qa_test_tip
#      ## view is 'tip_default', refresh to current tip? [y|n|q] (n) y    (continuing.....)
#      ade useview msnielse_oggcore_12_1_2_1_0_adc6140259_20140907_qa_test_tip -exec ade refreshview
#
##############################################################################
PROG=${BASH_SOURCE[0]##*/}

usage() {
 [ $# -gt 0 ] && echo "** error: $@" 1>&2 && echo
 cat<<EOF
 Usage: $PROG [-t|-l|-L{label}] [-s {series}] [-p {product}] {desc}

 Create an ADE view, auto-naming views consistently, auto-setting some ADE options,
 and allowing shortcuts specifically for GoldenGate. Consistently named views (such
 as using or 'tip' or 'latest' in the name) also work with the 'lsview' ADE script.

 Options/args:
   {desc}       description, added to view name ("bug 123456789" or "testing foo")
    -h          print usage
    -n          don't create the view, just show what would be run
    -u          use the newly created view (run "ade useview..." after view creation)
    -q          quiet - be less verbose
    -v          verbose - be more verbose
    -y          assume "yes" to all questions (e.g, "create the view? [y|n|q] (n)")

 Setting the ADE label:
    -t          use "-tip_default" (default!); auto-refreshes newly created view
    -l          use "-latest" for view
    -L {label}  use given named label for view

 Determining the ADE product/series:
    -p {prod}     product name (approximate), eg: adp, core
    -P {prod}     product name (exact), eg: OGGADP, OGGCORE, RDBMS...
    -s {series}   series name, eg: "OGGCORE_MAIN_PLATFORMS", or abbreviated
                  as "main", "11.2", "12.1.2"...
EOF
  return 0
}

##############################################################################
usage_exit() { # print usage and exit...
  local ret
  [ $# -gt 0 ] && ret=$1 && shift
  usage "$@"; exit $ret
}

die() { # print error message and exit...
  printf "\n** error: $@\n" 1>&2
  exit 2
}

info() {  # print info message to user, unless 'quiet'
  local n='\n'
  [ $# -gt 0 -a "$1" = "-n" ] && shift && n=""
  $quiet || printf "$@${n}" | sed 's/^/## /'
  return 0
}

clean_string() { # replace special chars w/ "_"
  sed 's/[^a-zA-Z0-9_]/_/g; s/__*/_/g; s/^ *//; s/ *$//'
  return 0
}

to_lower() { # convert to upper/lower
  tr '[A-Z]' '[a-z]' | clean_string
  return 0
}

to_upper() { # convert to upper/lower
  tr '[a-z]' '[A-Z]' | clean_string
  return 0
}

get_tstamp() { # sortable timestamp YYYYMMDD (20120630), instead of: date '+%Y-%m-%d', '+%Y-%b-%d'
  date '+%Y%m%d'
}

get_viewname() { # return view name, optionally include date/host/desc; give {desc} as arg
  local series_desc view_desc
  [ $# -gt 0 ] && view_desc="$@" || view_desc="temp"

  [ "$LABEL" = "" ] \
     && series_desc=$(echo "$SERIES" | sed 's/_PLATFORMS//' | sed 's/-series//') \
     || series_desc=$(echo "$LABEL" | sed 's/_PLATFORMS//' | sed 's/\.[0-9][0-9][0-9][0-9]$//')

  view_desc="$(whoami) ${series_desc} $(hostname) $(get_tstamp) ${view_desc} $LABEL_TYPE"
  echo "$view_desc" | sed 's/[-_]default//g' | to_lower
}

ask() { # print question, ask {y/n/q} and return true, false, or exit
  local resp
  if $do_ask ; then
    printf "$@" | sed 's/^/## /'
    read -n1 -p " [y|n|q] (n) " resp
    [ "$resp" = "q" ]  && { printf "   (exiting......)\n" ; exit 2; }
    [ "$resp" != "y" ] && { printf "   (skipping.....)\n" ; return 2; }
    printf "    (continuing.....)\n"
  fi
  return 0
}

print_debug() { # debug tracing
  if $verbose; then
    [ $# -gt 0 ] && echo "$@"
    echo "  SERIES=\"$SERIES\" (PREF_SERIES=\"$PREF_SERIES\")"
    echo "  LABEL=\"$LABEL\""
    echo "  LABEL_TYPE=\"$LABEL_TYPE\""
    echo "  PROD=\"$PROD\""
  fi
}

################################################################################
# The view may be created from an exact named label, or be 'latest' or 'tip'
# * LABEL => this is the named label, if LABEL_TYPE=-label
# * LABEL_TYPE => will be "-label", "-tip_default", or "-latest"
# The view_name is created from {view-type, desc, series, prod, user, host, date}
################################################################################
LABEL=
LABEL_TYPE=
PREF_SERIES="MAIN"  # will guess "preferred series", unless LABEL or SERIES is set
PROD=
OPTS=
SERIES=
VIEW_NAME=

#run=echo          # debug: just echo commands that would be run
is_tip=false
use_view=false
print_only=false
verbose=false
quiet=false
do_ask=true
ret=2

OPTIND=1
while getopts hL:lnp:qs:tuvy opt ; do
  case "$opt" in
     h) usage_exit 0
        ;;
     L) LABEL="$OPTARG"       # view label => -label {label_name}
        LABEL_TYPE="-label"
        ;;
     l) LABEL_TYPE="-latest"  # view label => -latest
        LABEL=
        ;;
     n) print_only=true       # don't actually run anything
        #quiet=true
        ;;
     P) PROD=${OPTARG}        # exact product name => OGGADP, OGGCORE, ...
        ;;
     p) # could put a default list of supported prods & aliases in ~/.aderc
        case "$(echo ${OPTARG} | tr '[A-Z]' '[a-z]' | sed 's/^ogg//' )" in
           core )            PROD="OGGCORE"     ;;
           adp  )            PROD="OGGADP"      ;;
           db   )            PROD="OGGDB"       ;;
           mon  | monitor  ) PROD="OGGMON"      ;;
           veri | veridata ) PROD="OGGVDT"      ;;
           dir  | director ) PROD="OGGDIRECTOR" ;;
           *) die "abbreviated product name unknown (\"$OPTARG\"); to specify full product name, use: -P {product}" ;;
        esac
        ;;
     q) quiet=true
        ;;
     s) PREF_SERIES=${OPTARG}       # approx series (12.1.2, MAIN, etc) =>  create view w/ {PRODUCT}.*{SERIES}
        ;;
     t) is_tip=true                 # view => -tip_default  (also, refreshes after view is created)
        LABEL_TYPE="-tip_default"
        LABEL=
        ;;
     u) use_view=true               # use the view, after creating it
        ;;
     v) verbose=true
        ;;
     y) do_ask=false                # don't ask "continue?" before creating the view
        OPTS="$OPTS -force_broken"  # don't ask "are you sure?" if label is broken/incomplete/source-only
        ;;
     *) usage_exit 2
        ;;
  esac
done; shift $((OPTIND-1)); OPTIND=1

[ $# -gt 0 -a "${1:0:1}" = "-" ] && usage_exit 2 "expecting argument, found option ($1): $@"
[ $# -gt 1 -a "${2:0:1}" = "-" ] && usage_exit 2 "expecting argument, found option ($2): $@"

[ "$LABEL" = "" -a "$LABEL_TYPE" = "" ] && LABEL_TYPE="-tip_default" && is_tip=true
[ "$PROD" = "" -a "$PREF_SERIES" != "" ] && echo "$PREF_SERIES" | egrep -q "_" && PROD=$(echo "$PREF_SERIES" | cut -f1 -d_)

# if PROD=OGGCORE, strip PROD from PREF_SERIES in case it's "OGGCORE_{VERSION}" instead of just "{VERSION}"
[ "$PROD" != "" ] && PREF_SERIES=$(echo "$PREF_SERIES" | sed "s/^${PROD}_//")

print_debug "configure...."
if [ "$LABEL" = "" ]; then
  [ "$SERIES" = "" -a "$PREF_SERIES" = "" ] && die "a series, label, or product is required"

  [ "$SERIES" = "" ] \
     && info "Search product \"$PROD\" for series \"$PREF_SERIES\"..." \
     && SERIES=$(ade showseries -product "$PROD" 2>&1 |egrep -i "${PROD}.*_${PREF_SERIES}" | sort -r -t_ -k2,2 | head -1 | sed 's/  *//')

  [ "$SERIES" = "" ] && die "no matching series found for product: $PROD (series: $PREF_SERIES)"

  SERIES="-series $SERIES"
fi

print_debug "create view using:"
VIEW_NAME=$(get_viewname $@)

if $print_only ; then
  printf "$VIEW_NAME\n"
  info "To create view, run:"
  info "   ade createview $OPTS $SERIES $LABEL_TYPE $LABEL $VIEW_NAME"
  ret=0
else
  info "Creating view: $VIEW_NAME"

  [ "$ADE_VIEW_ROOT" != "" ] && die "can't create view; already in a view ($ADE_VIEW_ROOT)"

  ask "Execute:\n   ade createview $OPTS $SERIES $LABEL_TYPE $LABEL $VIEW_NAME\n Create the view?" \
    && $run ade createview $OPTS $SERIES $LABEL_TYPE $LABEL $VIEW_NAME \
    && ret=0

  $is_tip && [ $ret -eq 0 ] \
    && ask "view is 'tip_default', refresh to current tip?" \
    && $run ade useview $VIEW_NAME -exec "ade refreshview" \
    && ret=0

  $use_view && [ $ret -eq 0 ] \
    && $run ade useview $VIEW_NAME \
    && ret=0
fi

exit $ret

