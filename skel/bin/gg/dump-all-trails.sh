#!/bin/bash

PROG_PATH=${BASH_SOURCE[0]}      # this script's name
PROG_NAME=${PROG_PATH##*/}       # basename of script (strip path)
PROG_DIR="$(cd "$(dirname "${PROG_PATH:-$PWD}")" 2>/dev/null 1>&2 && pwd)"

print_rec=$PROG_DIR/print-trail-rec-summary.sh

dump_all_trails() {
  for f in $( find $@ -name "*00*[0-9]" )
  do 
     out=${f}.summary.txt
     [ -f $f ] && printf "** warning: file exists (not overwriting): $f\n"
     echo "======== $f === $(date)"
     [ ! -f $out ] && $print_rec ${f} > $out
     grep -n2 Restart $out
     echo ============== $f === $(date) 
     echo 
  done
}

[ ! -e $print_rec ] && printf "** error: script not found, $print_rec\n" && exit 2

dump_all_trails "$@"

