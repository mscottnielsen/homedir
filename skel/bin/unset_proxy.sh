#!/bin/bash

# script path, filename, directory
PROG_PATH=${BASH_SOURCE[0]}      # this script's name
PROG_NAME=${PROG_PATH##*/}       # basename of script (strip path)
PROG_DIR="$(cd "$(dirname "${PROG_PATH:-$PWD}")" 2>/dev/null 1>&2 && pwd)"

[ $# -eq 0 ] && opts="-u" || opts="$@"

. $PROG_DIR/set_proxy.sh $opts

