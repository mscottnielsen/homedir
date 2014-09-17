#!/bin/bash
#
# Assumes view name is meaningful, e.g.,
#   e.g., ADE_VIEW_NAME=msnielse_bugfix_adp_main_2012_apr_27_bug13947264_tip
#
#########################################################################

DO_ASK=true

#########################################################################
normalize(){
  sed  "s/  */_/g; s/--*/_/g; s/__*/_/g; s/^_//; s/_*$//"
}

#########################################################################
get_desc() {
  local stamp=$(date '+%Y%m%d')
  local name=$(whoami)
  echo "$name $stamp $@" | normalize | sed 's/fix_fix_/fix_/g'
}

#########################################################################
ask() {
  # print question, ask {y/n/q} and return true, false, or exit
  local resp
  printf "\n=== $@ "
  if $DO_ASK ; then
    read -n1 -p " => continue? [y|n|q] (n) " resp
    [ "$resp" = "q" ]  && { printf "   (exiting......)\n" ; exit 2; }
    [ "$resp" != "y" ] && { printf "   (skipping.....)\n" ; return 2; }
  fi
  printf "   => yes (continuing.....)\n"
  return 0
}


#########################################################################
get_bugnum() {
   local bnum=$(echo "$@" | tr '[-_]' '\12' | sed -n '/bug/ {n;p}' | tail -1)
   [ ${#bnum} -gt 3 -a "${bnum}" -eq "${bnum}" ] 2>/dev/null && echo "$bnum" && return 0
   return 1
}

#########################################################################
begin_trans() {
  local bug bug_desc desc opt tx_name

  [ $# -gt 0 ] && desc="$@" || desc="fix"
  bug=$(get_bugnum "$ADE_VIEW_NAME")
  [ "$bug" = "" ] && bug=$(get_bugnum "$desc")


  [ "$bug" != "" ] \
    && opt="$opt -bug $bug" \
    && bug_desc="bug_$bug"

  echo "tx_name=\$(get_desc "$bug" "$bug_desc")"

  tx_name=$(get_desc "$bug" "$desc" "$bug_desc")

  echo "bug: $bug"
  echo "desc: $desc"
  echo "transaction: $tx_name"

  ask "ade begintrans $tx_name $opt" \
    && ade begintrans $tx_name $opt
}

usage() {
   echo "Usage: $0  [ade_txn_desc]"
   echo "  Creates an ade transaction with the given description, adding timestamp, user name, bug number/info."
}

if [ "$1" = "-h" ]; then
  usage
else
  begin_trans $@
fi

