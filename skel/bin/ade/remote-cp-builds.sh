#!/bin/bash
#########################################################################
##
## Create a view, tar up the relevant files in "dist", and post to "ipubs".
##
#########################################################################

# vim folding tips:
#   to open a fold, move cursor to fold and: zo
#   to close all folds: zm / zM
#   to open all folds: zr / zR


##### variables {{{1

# two views currently set up for use with this script:
view_core=msnielse_oggcore_main_clean_latest
view_adp=msnielse_adp_main_clean_tip

# copy files to remote directory on given host, as user
rmtuser=$(whoami)
rmthost=localhost

# old: /net/rtdc1017nap/vol/gg_shared2/shared2/Public/ATG/Repository/fileserver/builds/snapshots/GoldenGate
#      /mnt/shared/Public/ATG/Repository/fileserver/builds/snapshots/GoldenGate
# new: lrwxrwxrwx 1 msnielse ggsdba 51 Dec 30 10:31 /home/msnielse/S -> /net/slcnas484/export/gg_shared2/shared2/Public/ATG
dir=$HOME/S/Repository/fileserver/builds/snapshots/GoldenGate

# Disable remote copy, either set "run" var or pass in "-n" option
run=
#run=_do_noop

##########################################################
## logging, uses external 'log' function
LOG=$HOME/remote_copy${run}_log.txt

PROG_PATH=${BASH_SOURCE[0]}  # get calling script's path
PROG_DIR=$(cd "$(dirname "${PROG_PATH:-$PWD}")" 2>/dev/null 1>&2 && pwd)
log() { :; }   # define default no-op logger as fallback
. $PROG_DIR/../common/log.sh 2>/dev/null
: ${LOG_LEVEL:="INFO"}  # set logging level to {NONE, ERROR, WARN, INFO, DEBUG, TRACE}

# temp file, for things to clean up
TMPFILE_PREFIX=/tmp/cleanup.temp.$$
TMPFILE_VIEW=""

# ssh/scp commands and options
#ssh_cmd=ssh
#scp_cmd=scp
#ssh_opt=

# avoid feedback (e.g., "are you sure?") when running command (usage: $ssh_cmd "$ssh_opt")
ssh_cmd='ssh -Y'
scp_cmd='scp'
ssh_opt='-oStrictHostKeyChecking no'

#### variables }}}  

#########################################################################
_do_noop() {
  log INFO "[run-disabled] $* \n"
}

#########################################################################
# trap on error {{{1
# cleanup tmp files on exit. On any error, trap and exit, then cleanup
trap 'echo "cleaning up tmpfiles... $(test -f "$TMPFILE_VIEW" && rm -f "${TMPFILE_VIEW}" || log DEBUG "no tmpfile created")" && rm -f "$tmp" >/dev/null 2>&1' 0
trap "exit 2" 1 2 3 15
# }}}

#########################################################################
# print usage
#
usage() {
  printf "\n Usage: $0 [ adp | core | OGGCORE_MAIN | OGGADP_MAIN ]

   Arguments:
     Using pre-existing views (refreshes first):
        adp   - copy and scp OGGADP view to server, msnielse_adp_main_clean_tip
        core  - copy and scp OGGCORE view to server, msnielse_oggcore_main_clean_latest

     Dynamically creates and then destroys view:
        OGGCORE_MAIN - creates 'latest' label view from series OGGCORE_MAIN_PLATFORMS
        OGGADP_MAIN - creates 'tip' label view from series OGGADP_MAIN_PLATFORMS
  "
  return 0
}

#########################################################################
# to_lower {string} - convert to lower {{{1
# convert to lower, and change "-" to "_"
#
to_lower() {
  printf "$1" | sed -e 's/\(.*\)/\L\1/; s/-/_/g'
  return 0
} # }}}

#########################################################################
# get_storage  {view_name}  {{{1
#   print path to storage for the given view
get_storage() {
  local view="$1"
  ade lsviews -s -long  | egrep "^${view} |^$(whoami)_${view} " | awk -F\| '{ print $4 }' | sed 's/ *//g' | head -1
  return 0
}  # }}}

#########################################################################
# is_view {view-name} {{{1
#   Return true if the given arg is a view
#   Options/arguments:
#   {view_name}  -  either form of a view name, "{user}_view_name" or "view_name"
#                   (assuming current user owns the view)
is_view() {
  local view="$1"
  # return result of grep
  ade lsviews | egrep -q "^${view} |^$(whoami)_${view} "
} # }}}

#########################################################################
# is_series [product] {label_series} {{{1
#   Return true if the given arg is a valid label series for a product.
#   E.g., OGGCORE_MAIN_PLATFORMS, OGGCORE_11.2.1_PLATFORMS, OGGADP_MAIN_PLATFORMS, ...
#
#   If given one arg, it's assumed to be a label series, the first part of which is the product;
#   e.g., OGGCORE_MAIN_PLATFORMS => product is OGGCORE
#   Options/arguments:
#   {view_name}  -  either form of a view name, "{user}_view_name" or "view_name"
#                   (assuming current user owns the view)
is_series() {
  local series="" product=""
  [ $# = 1 ] && series="$1" && product=$(echo "$1" | cut -d_ -f1)
  [ $# = 2 ] && product="$1" && series="$2"

  [ "$product" = "" ] && return 3

  # return result of grep
  ade showseries -product  "$product" | sed 's/ *//g' | egrep -iq "^${series}$"
} # }}}

#########################################################################
# get_distdir {series} {view} {{{1
#
#  Get the "dist" directory for a given series name and view,
#  e.g.,: {storage}/${series}/dist => /path/to/view_storage/msnielse_adp_main_clean_tip/oggadp/dist
#
#  Options/arguments:
#   {series} -  series name, e.g.,  OGGADP or OGGCORE
#   {view} -  view name, e.g.,  mnielsen_view_name
#
#
get_distdir() {
  [ $# -lt 1 ] && log ERROR "** [error] expecting argument: ADE series name" && return 2
  local series=$(to_lower $1)
  shift

  [ $# -lt 1 ] && log ERROR "** [error] expecting argument: view name to with files to copy (series=$series)" && return 2
  local view=$1

  local storage=$(get_storage $view)
  [ ! -d "$storage" ] \
      && log ERROR "** [error] view storage directory doesn't exist: view=\"$view\", series=$series, storage=\"$storage\"\n$(ls -ld $storage)" \
      && return 2

  local distdir=${storage}/${series}/dist
  [ ! -d "$distdir" ] \
      && log ERROR "** [error] directory doesn't exist: \"$distdir\" \n====\n $(ls -ld $distdir)\n====" \
      && return 2

  echo $distdir
  return 0
} # }}}

#########################################################################
# get_files [-s] {dir} - get "dist" files from oggcore or oggadp {{{1
#  Get 'dist' files, for either OGGADP or OGGCORE (assuming a max directory depth of 3 is ok)
#    * oggcore builds are at depth=2.
#    * oggadp builds at depth=3 returns both bundled adapter+core (depth=1), plus just plain adapters (depth=3).
#  Arguments & options:
#     -s  get short names only, remove everything up to and including the "dist" directory.
#     {dir}  - the dist directory containing the files
#
get_files() {
  [ $# -gt 1 -a "$1" = "-s" ] && do_short=true && shift 1
  [ $# -lt 1 ] && log ERROR "** [error] expecting argument: dist directory containin files to copy" && return 2
  local distdir="$1" ret=""

  [ ! -d "$distdir" ] \
     && log ERROR "** [error] directory doesn't exist: \"$distdir\" \n====\n $(ls -ld $distdir)\n====" \
     && return 2

  # don't print anything else to stdout, other than filenames
  ret=$(find $distdir -maxdepth 2 ! -regex '.*/\..*' -follow \( -name '*Gen*.zip' -o -name '*ora11g*.zip' -o -name 'gg*Adapter*.zip' -o -name 'gg*Writer*.zip' \)  -print )

  # optionally strip distdir from the beginning of the path
  [ "$do_short" = "true" ] && echo  "$ret" | tr ' ' '\12' |sed "s:^.*${distdir}/::" || echo $ret | tr ' ' '\12'
}  # }}}

#########################################################################
# refresh [-tip|-latest] {view} - refresh the given view {{{1
# If view has "_latest" in the name, will refresh to "-latest", otherwise will assume "-tip" (i.e.,
# no option is given to "refreshview")
#
refresh_view() {
  local opt=
  [ "$1" = "-tip" ] && opt="" && shift
  [ "$1" = "-latest" ] && opt="-latest" && shift
  local view=$1

  log INFO "refreshing view: $view $opt"

  # verify view exists
  ade lsviews | egrep -q "^${view} |^$(whoami)_${view} " || return 2

  # if view is created with -default-tip, no argument needed for refreshview
  ade useview $view -exec "pwd" -exec "ade refreshview $opt"
  return 0
} # }}}

#########################################################################
# cleanup, delete temp view {{{1
cleanup() {
  local view="$1" check="status unknown"
  ade lsviews | egrep -q "^[a-z_]*${view} " &&  check="exists" || check="does not exist"
  log INFO "[cleanup]:  destroying view, if it still exists: \"$view\"  (view: ${check})"
  [ "$check" = "exists" ] && ade destroyview -force -rm_twork ${view}
} # }}}

#########################################################################
# Usage: do_copy [-tip|-latest] {view_name} {{{1
#   view     =>   view name, e.g., msnielse_oggcore_main_clean_latest or msnielse_adp_main_clean_tip
#   label    =>   ADE label, e.g., OGGADP_MAIN_PLATFORMS_120103.0700 or OGGCORE_MAIN_PLATFORMS_120106.1800
#   series_prefix => first part of series name; e.g., OGGADP or OGGCORE (vs. series_prefix2
#                    which is the first two parts: e.g., OGGCORE_MAIN or OGGADP_MAIN)
do_copy() {
  local opt="" ret="" refresh=false view="" files="" tmp=""
  [ "$1" = "-tip" -o "$1" = "-latest" ] && opt="$1" && refresh=true && shift
  view="$1" && shift

  if [ "$opt" = "" ]; then
    # set tmp="tip" or tmp="latest", assuming view naming convention view_latest or view_tip
    tmp=$(echo "$view" | sed 's/^.*[-_]//; s/ *//')
    case "$tmp" in
     latest )
        refresh=true
        opt="-latest"
        ;;
     tip )
        refresh=true
        opt=
        ;;
     * )
        log WARN "can't tell if view is tip or latest ($tmp): $view"
        ;;
     esac
  fi

  [ $# -gt 0 ] && files="$@"

  if [ "$refresh" = "true" ]; then
     refresh_view $opt $view || return 2 # new "-tip" views, must refresh before use
  fi

  # Dated remote dir allows multiple daily runs, OR
  # if same label is somehow re-used/re-generated for consecutive days
  local label=$(ade lsviews | awk -v view=$view -F\|  "/$view / { print \$2 }" | sed 's/ *//g')
  local series_prefix=$(echo "$label" | sed 's/_.*//')
  local rsubdir=$(echo "$label" | cut -d_ -f1-3)
  local rdir=${dir}/${series_prefix}/${rsubdir}/${label}__$(date '+%Y-%m-%d_%H-%M')
  local rmtdir="${rmtuser}@${rmthost}:$rdir"
  local tmpsum=/tmp/md5.${label}.copying.txt
  local tmpsum_done=md5.${label}.done.txt
  local distdir=$(get_distdir $series_prefix $view)

  log DEBUG "[do_copy] copy files, view=\"$view\" series=\"${series_prefix}\" label=\"${label}\" rmt=\"$rmtdir\" distdir=\"$distdir\""
  [ "$files" = "" ] && files=$(get_files -s $distdir)

  # debug logging begin... {{{2
  log DEBUG "[do_copy] ====files: ${distdir}\n${files}\n===="
  (cd $distdir && for f in ${files}; do ls -ld $f; done 2>&1) 2>&1 | log DEBUG "[do_copy]"
  # }}} ...debug logging end

  # begin error checking... {{{2
  # (1) error checking: make sure there is a list of readable files, return error if not
  [ "$files" = "" ] && log ERROR "[do_copy] no files found to copy: $series_prefix $view" && return 2

  # (2) error checking: get error msg (stderr redirect is correct: stdout to dev/null, and stderr to msg)
  local tmp_err_msg=$( cd $distdir 2>&1 >/dev/null && ls $files 2>&1 >/dev/null )
  [ $? -ne 0 ] && log ERROR "[do_copy] invalid file list: $series_prefix $view => $tmp_err_msg" && return 2
  #  }}} ..end error checking

  printf "===============================================\n"
  printf "Generate md5sum before copy on local files: "
  # generate md5sum, copy to remote. If this is incorrect after copy, report error
  ( cd $distdir > /dev/null && md5sum $files ) | tee $tmpsum | wc -l

  # create remote dir; copy md5sum as md5.copying.txt; after transfer complete, rename md5sum as "md5.done.txt"
  $run $ssh_cmd "$ssh_opt" ${rmtuser}@${rmthost} "test ! -d $rdir && mkdir -p $rdir"
  printf "Copying to remote: $rmtdir"
  $run $scp_cmd "$ssh_opt" $tmpsum $rmtdir/

  # instead of scp, preserve directory structure by using local/remote tar (disable compression for zip's)
  ( $run cd $distdir && $run tar -h -cf - $files | $run $ssh_cmd "$ssh_opt" ${rmtuser}@${rmthost}  "tar -xf - -C $rdir" )

  [ -f $tmpsum ] && rm $tmpsum

  # if md5sum is ok, move to "md5.copying" to "md5.done"
  local md5_tempfile="$(basename $tmpsum)" remote_md5_temp="$rdir/$md5_tempfile" remote_md5_done="$rdir/$tmpsum_done"

  printf "Verify md5sum on remote files: \n"
  $run $ssh_cmd "$ssh_opt" ${rmtuser}@${rmthost} "cd $rdir && md5sum -c $md5_tempfile && mv $md5_tempfile $remote_md5_done"
  ret=$?

  printf "===============================================\n"

  log INFO "do_copy finished (ret=$ret), closing ${rmtdir}"
  return 0
} # }}}

#########################################################################
# function copy_view [-latest|-tip] {series_prefix} [do_copy_options]   {{{1
#   Create a view either as "tip" or "latest", and copies it (calls do_copy).
#   Args/opts:
#    -latest     -  create a view with "latest" label
#    -tip        -  create a view with "-tip_default" option
#    series_prefix  - e.g: OGGADP_MAIN or OGGCORE_MAIN (the "_PLATFORMS" is automatically appended.)
#
#   Note that a new view should be refreshed after created, or else it won't have the latest 'tip'.
#
copy_view() {
  local opt create_view_opt
  [ "$1" = "-latest" ] && create_view_opt="-latest"      && opt="$1" && shift
  [ "$1" = "-tip" ]    && create_view_opt="-tip_default" && opt="$1" && shift

  # series_prefix2 => first two parts of series name; e.g., OGGCORE_MAIN or OGGADP_MAIN
  local series_prefix2="$1" && shift
  local series=${series_prefix2}_PLATFORMS
  echo "$series_prefix2" | egrep 'PLATFORMS|GENERIC' >/dev/null && series=${series_prefix2}

  local view=$(to_lower temp_$$_${series_prefix2}${opt})

  log DEBUG "[copy_view] creating and refreshing view: \"$view\" ${create_view_opt}"

  [ ""  = "${TMPFILE_VIEW}" ] &&  TMPFILE_VIEW=${TMPFILE_PREFIX}.${view}
  [ -f "${TMPFILE_VIEW}" ] &&  log ERROR "** error:  temp file exists ( $TMPFILE_VIEW ): exiting..." && return 3 || touch "${TMPFILE_VIEW}"

  log INFO "[copy_view] creating view : \"$view\""
  ade createview ${view} -series ${series} ${create_view_opt}

  log DEBUG "[copy_view] copying files: \"$view\""
  do_copy $opt $view $@
  ret=$?

  log DEBUG "[copy_view] cleanup/destroyview: \"$view\""
  cleanup "${view}"   # destroyview

  log DEBUG "[copy_view]:  completed: \"$view\" / return=$ret"
  return $ret
}  ### }}}

#########################################################################
# main
#########################################################################

# set to e.g., "-latest" (default) or "-tip"
copy_view_options=""

[ $# -eq 0 ] && usage && exit 2
type ade || exit 2

################
# get options
#
OPTIND=1
while getopts d:hH:ntu: option ; do
  case "$option" in
  d)
    dir="${OPTARG}"
    log DEBUG "[option] using remote directory: $dir"
    ;;
  h)
    usage
    exit 2
    ;;
  H)
    rmthost="${OPTARG}"
    log DEBUG "[option] using remote host: $rmthost"
    ;;
  n) # disable remote copy (debug)
    run=_do_noop
   ;;
  t)
    log DEBUG "[option] create view using '-tip'"
    copy_view_options="-tip"
   ;;
  u)
    rmtuser="${OPTARG}"
    log DEBUG "[option] using remote username: $rmtuser"
    ;;
  *)
    log ERROR "** [error] unknown option" && usage | log INFO && exit 2
    ;;
  esac
done

shift $((OPTIND-1)); OPTIND=1


################
# do work
#
for x
do
  # copy specific view. View should be named {view_name_tip} or {view_name_latest} to be properly refreshed
  if is_view "$x"; then
    log INFO "copy an existing view: $x"
    do_copy "$x"
    continue
  fi

  # specific series, dynamically create a view (OGGCORE_MAIN_PLATFORMS, OGGADP_MAIN_PLATFORMS)
  if is_series "$x"; then
    log INFO "given a valid label series: $x"
    copy_view $copy_view_options "$x"
    continue
  fi

  # predefined values for common labels, views
  y=$(to_lower $x)
  if [[ "$y" =~ "oggadp"  || "$y" =~ "adp"  ]]
  then
     copy_view $copy_view_options OGGADP_MAIN || exit 2

  elif [[ "$y" =~ "oggcore" || "$y" =~ "core" ]]
  then
     copy_view $copy_view_options OGGCORE_MAIN || exit 2
  fi
done


# ------------------------------------------------------------------------
# Modelines: {{{1
# vim:ts=8 fdm=marker

