#!/bin/bash

########################################################################
PROG_PATH=${BASH_SOURCE[0]}
PROG_NAME=${PROG_PATH##*/}

usage() { cat<<EOF
 Delete old backups of labels copied from ADE, typically run as cronjob.
 Usage: $PROG_NAME [-k {num}] [-h] {oggcore|oggadp|{product}}
 Options:
  -n        dry-run; don't delete, only show what would be deleted
  -D {dir}  change the storage directory. Default storage
            directory: $SHARE
  -k {num}  number of builds to keep; the rest will be deleted
  -h        print this usage message
  -v        verbose

EOF
  return 0
}


log() {
    # log if 'verbose' mode, to stdout
    $VERBOSE || return 0
    insert_prefix() {
        sed 's/^./#\[info\] &/'
        return 0
    }
    [ $# -eq 0 ] && insert_prefix 1>&2 || printf -- "$@" | insert_prefix 1>&2
    return 0
}

# convert to uppercase (bash-3.2 doesn't support ${x^^})
to_upper() {
    echo "$@" | tr '[a-z]' '[A-Z]'
}

check_dir() {
    [ -d "$1" ] && return 0
    echo "** error: directory does not exist: $1" 1>&2
    ls -ld "$1"
    return 2
}


safe_remove_dir() {
    # Removes the given directories, checking first to see if the directory is
    # currently being copied (check for file "*copying*.txt", if dirname contains
    # today's date). Returns error if not given a directory as an argument.

    local dir in_progress=0
    local ts1=$(date '+%Y-%m-%d')  # YYYY-mm-dd
    local ts2=$(date '+%y%m%d')    # yymmdd

    for dir ; do
        if [ ! -d "$dir" ] ; then
            echo "** error: not a directory (ignoring): $dir"
        else
            if echo "$dir" | egrep "$ts1|$ts2"
            then
              in_progress=$(find "$dir" -name "*copying*txt" | wc -l)
              if [ $in_progress -gt 0 ]; then
                 echo "** warning: not deleting directory, copy in progress: ${dir}"
                 ls -l "$dir"
                 continue
              fi
            fi
            log "deleting dir: $dir\n"
            $do_run rm -fr "$dir"
        fi
    done
}


get_label_timestamp() {
    # convert: OGGADP_MAIN_PLATFORMS_140625.0703__2014-06-26_02-40 => 140625.0703
    ls -1 "$1" | egrep '_[0-9]{6}\.[0-9]{4}' | sed 's/^.*\([0-9]\{6\}\.[0-9]\{4\}\)/\1/; s/__.*//' | sort
}


get_copy_timestamp() {
    # convert: OGGADP_MAIN_PLATFORMS_140625.0703__2014-06-26_02-40 => 2014-06-26_02-40
    ls -1 "$1" | sed 's/^.*__//' | sort
}


get_filelist_to_remove() {
   local ts total=0 to_delete=0 keep=5 label_ts=false
   local opt OPTIND
   while getopts ck:l opt; do
       case "$opt" in
           l) label_ts=true  ;;   # log "use label timestamp\n"
           c) label_ts=false ;;   # log "use copy timestamp (default)\n"
           k) keep=${OPTARG} ;;
           *) echo "** get_filelist_to_remove: unknown option ($@)" 1>&2
              return 2;;
       esac
   done; shift $((OPTIND-1)); OPTIND=1

   local dir=$1
   check_dir "$dir" || return 2

   get_ts() {
       if $label_ts ; then
           get_label_timestamp $@
       else
           get_copy_timestamp $@
       fi
   }

   list_files() {
       if $label_ts ; then
           ls -1d ${1}/*${2}__*
       else
           ls -1d ${1}/*__${2}
       fi
   }

   total=$(get_ts "$dir" | wc -l)
   [ $total -ge $keep ] && (( to_delete = total - keep ))

   #log "...total=$total/delete=${to_delete}/keep=$keep/dir=$dir/label=$label_ts/timestamps: $PWD\n"
   #get_ts "$dir" | log

   for ts in $(get_ts "$dir" | head -${to_delete}); do
       list_files ${dir} ${ts}
   done
   return 0
}

cleanup_series() {
    # Usage: cleanup_series {label_series_dir}
    # remove old backups in the given directory for a given product/series
    # eg, OGGADP/OGGADP_MAIN_PLATFORMS or OGGADP/OGGADP_11.1.1.0_PLATFORMS

    [ $# -ne 1 ] && { echo "** error (cleanup_series): expecting {series_dir}; given: $@" 1>&2; return 2; }

    local dir prod dir_count to_delete
    prod=$(dirname $1)  # e.g., OGGCORE or OGGADP
    dir="$1"  # relative path, OGGCORE/OGGCORE_11.2.1.0.1_PLATFORMS,
              # contains OGGCORE_{version}_PLATFORMS_140614.1403__2014-06-18_03-41

    # Can remove old timestamps for each label (my timestamps, from when the view was
    # copied), and keep only most recent build for each dated (non-RELEASE) label.
    # OGGADP/
    #  |-OGGADP_11.2.1.0.1_PLATFORMS/
    #  |     |--OGGADP_11.2.1.0.1_PLATFORMS_130922.1200__2014-04-24_02-20
    #  |     |--OGGADP_11.2.1.0.1_PLATFORMS_130923.1200__2014-04-24_02-20
    #  |     \--OGGADP_11.2.1.0.1_PLATFORMS_RELEASE__2014-06-26_02-00
    #  \-OGGADP_MAIN_PLATFORMS/
    #        \--OGGADP_MAIN_PLATFORMS_140607.0703__2014-06-09_02-40

    log "\n== $prod => existing dirs before cleanup: $dir\n"
    ls -1d $dir/*_*_* 2>&1 | sort | sed 's/^/#  /' | log

    log "== $prod => keeping latest timestamp for label: $(basename ${dir})\n"
    safe_remove_dir $(get_filelist_to_remove -c -k $KEEP $dir)

    log "== $prod => keeping latest dated labels: $(basename ${dir})\n"
    safe_remove_dir $(get_filelist_to_remove -l -k $KEEP $dir)
  }

########################################################################
# Usage: do_clean { oggadp | oggcore | {series} }
# Removing old labels/timestamps from the storage directory.
cleanup_product() {
    local arg dir prod
    for arg; do
        prod=$(to_upper $arg)
        log "\n====== cleaning product: $prod ======\n"
        printf "## Storage directory: $PWD => $prod\n"
        for dir in $(ls -1d ${prod}/${prod}_*); do
           if [ -d "$dir" ]; then
             log "## Purge old builds (keep=$KEEP): $dir\n"
             cleanup_series $dir  # eg, OGGCORE/OGGCORE_11.2.1.0.18_PLATFORMS
           else
             log "**error: not a directory (ignoring): $prod => $dir\n"
           fi
        done
    done
}

########################################################################
# Updated to better handle the constantly shifting file systems:
# product storage dir is either GoldenGate/OGGADP/.. or GoldenGate/OGGCORE/...
#  new: lrwxrwxrwx 1 msnielse /home/msnielse/S -> /net/slcnas484/export/gg_shared2/shared2/Public/ATG
#  old: /net/rtdc1017nap/vol/gg_shared2/shared2/Public/ATG/Repository/fileserver/builds/snapshots
SHARE=$HOME/S/Repository/fileserver/builds/snapshots/GoldenGate
do_run=
KEEP=5
VERBOSE=false

OPTIND=1
while getopts D:hk:nv opt; do
  case "$opt" in
  k) KEEP=${OPTARG}   # number of records to keep
     ;;
  n) do_run=echo
     ;;
  D) SHARE=${OPTARG}
     ;;
  v) VERBOSE=true
     printf "** enabling verbose output (verbose=$VERBOSE)\n" 1>&2
     ;;
  h) usage
     exit 2
     ;;
  *) echo "** unknown option given ($@)" 1>&2
     usage
     exit 2
     ;;
  esac
done ; shift $((OPTIND-1)); OPTIND=1

if [ "$do_run" = "echo" ]; then
    printf "## Warning: dry-run enabled, no changes will be made (verbose=$VERBOSE).\n" 1>&2
fi

[ $# -eq 0 ] && { usage ; exit 2; }

check_dir "$SHARE" || exit 2
cd $SHARE || { printf "** error: can't read directory: $SHARE\n"; exit 2; }

cleanup_product "$@"

