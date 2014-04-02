#!/bin/bash

# script path, filename, directory
PROG_PATH=${BASH_SOURCE[0]}      # this script's name
PROG_NAME=${PROG_PATH##*/}       # basename of script (strip path)
PROG_DIR="$(cd "$(dirname "${PROG_PATH:-$PWD}")" 2>/dev/null 1>&2 && pwd)"

GET_PW_SCRIPT=$PROG_DIR/ssop.sh

usage() { cat<<EOF
   $PROG_NAME [wget_script]
   Given a wget script from the Oracle support site, run it
   substituting your SSO password for the value in the script
EOF
    return 0
}

run_script() {
  for wg ;  do
    [ ! -f $wg ] \
      && { printf "** error: wget download script file not found: $wg\n\n" ; usage ; return 2; }
  done

  export SSO_PASSWORD=$($GET_PW_SCRIPT get)
  for wg ; do
    sed -i.bak 's/^SSO_PASSWORD=/#&/'  $wg
    . $wg
  done
}

#wget-p16441092_112106_HP64.zip.sh
#wget.p16232377_112105_HPUX-IA64.zip.sh
#wget.p16404972_112105_HPUX-IA64.zip.sh
#wget.p16942464_112106_SOLARIS64.zip.sh

[ $# -eq 0 ] && { usage ; exit 2; }

[ ! -f $GET_PW_SCRIPT ] && { printf "** error: get password script not found: $GET_PW_SCRIPT\n" ; exit 2; }

run_script "$@"


