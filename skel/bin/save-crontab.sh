#!/bin/bash

save_crontab() {
    local outdir=$HOME outfile=out-crontab
    [ $# -gt 0 ] && outdir=$1
    [ -f "$outdir" ] && { outdir=$(dirname $outdir) ; outfile=$(basename $outdir); }
    outfile="${outdir}/${outfile}-$(hostname)-$(date '+%Y-%b-%d_%H-%M').txt"
    [ -f $outfile ] && { printf "** error: file exists: $outfile\n"; return 2; }
    crontab -l > $outfile
}

save_crontab

