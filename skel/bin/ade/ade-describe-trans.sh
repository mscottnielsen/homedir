#!/bin/bash
#
# $ ade exec /usr/local/nde/ade/util/adhoc_query_scripts/changes_since_label.pl \
#     -intg -p OGG -b st_oggadp,main  \
#     -l OGGADP_MAIN_PLATFORMS_120905.0700 -since_time 20120905072500 | grep OGGADP_MAIN
#
# $ ade lshistory -nde Adapter
# $ ade lshistory Adapter/C_src//Common/UserExit/src/ueutil.c
##############################################################################

DAYS_AGO=7
LABEL_NAME=
LABELS_AGO=2
VERBOSE=false
DRY_RUN=false
SERIES=OGGADP_MAIN_PLATFORMS
PROD=$(echo $SERIES | cut -f1 -d_)

CHANGES_SCRIPT=/usr/local/nde/ade/util/adhoc_query_scripts/changes_since_label.pl

##############################################################################
#  either run, or just echo
run() {
  $DRY_RUN && echo "$@" || eval $@
}

##############################################################################
# get next-to-last label by default
list_txn() {
  local prev_last since_dt
  local since_dt=$(date -d "${DAYS_AGO} days ago" '+%Y%m%d%H%M%S')
  local prev_last=$(ade showlabels -series $SERIES | tail -${LABELS_AGO} | head -1)
  local prod=$(echo $PROD | tr '[A-Z]' '[a-z]')  # OGGADP => oggadp

  run ade exec $CHANGES_SCRIPT \
     -intg -p OGG -b st_oggadp,main -l $prev_last -since_time $since_dt | grep $PROD
}

##############################################################################
get_summary() {
  local txname=$1  # e.g., msnielse_ade_versioninfo_20121012_bug_14756041
  ade describetrans -long $txname | egrep '^label_name|^merged_to_branches|^date_created|^trans_name'
  return 0
}

##############################################################################
get_comments() {
  local txname=$1  # e.g., msnielse_ade_versioninfo_20121012_bug_14756041
  ade describetrans -long $txname | awk '/^comments/,/^trans_name/ { print $0 }' | grep -v '^trans_name'
  return 0
}

##############################################################################
usage() { cat<<EOF
  Usage: $0 [-d {days_ago} ] [ -l {label} | -L {labels_ago}] [transactions]
    Prints details of a given transaction; OR, if no transaction, prints
    a list of transactions, starting from {days} ago and/or since the given
    label and/or from the given number of labels ago.
EOF
  return 0
}

##############################################################################
# $ cat <( ade describetrans -long msnielse_ade_versioninfo_20121012_bug_14756041 | egrep '^label_name|^merged_to_branches|^date_created|^trans_name' ) \
#       <( ade describetrans -long msnielse_ade_versioninfo_20121012_bug_14756041 | awk '/^comments/,/^trans_name/ { print $0 }' | grep -v '^trans_name' ) \
#       | sed 's/\t\{1,\}/ /g; s/  *:  */: /; s/  *$//; s/  */ /g'
#
# label_name: OGGADP_MAIN_PLATFORMS_121012.0700
# merged_to_branches: main MON OCT 15 06:10:24 2012
# date_created: October 12, 2012, 08:05:28 A.M.
# trans_name: msnielse_ade_versioninfo_20121012_bug_14756041
# comments:
# 14756041 - OGG ADAPTERS REPORTED VERSION DOES NOT INCLUDE ADE LABEL IN REPORT


##############################################################################
# main
##############################################################################
OPTIND=1
while getopts d:hL:l:v opt ; do
  case "$opt" in
    d) DAYS_AGO=${OPTARG}
       ;;
    l) LABEL_NAME=${OPTARG}
       ;;
    L) LABELS_AGO=${OPTARG}
       ;;
    v) VERBOSE=true
       ;;
    * | h) usage
       exit 2
       ;;
  esac
done; shift $((OPTIND-1)); OPTIND=1

if [ $# -ge 1 ] ; then
  for t
  do
    get_summary $t && get_comments $t
  done | sed 's/\t\{1,\}/ /g; s/  *:  */: /; s/  *$//; s/  */ /g'
else
  # printf "** error: expecting a transaction name\n" && exit 2
  list_txn
fi


