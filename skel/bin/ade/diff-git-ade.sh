#!/bin/bash
###################################################
#
# Diff files in ADE with a git repo.
#
###################################################

. /etc/profile   # setup ADE

PROG_PATH=${BASH_SOURCE[0]}      # this script's name
PROG_NAME=${PROG_PATH##*/}       # basename of script (strip path)
PROG_DIR="$(cd "$(dirname "${PROG_PATH:-$PWD}")" 2>/dev/null 1>&2 && pwd)"
BIN_DIR=${PROG_DIR:="/home/msnielse/bin"}   # supporting scripts
MKTMP_VIEW_SH=$BIN_DIR/create-temp-view.sh
BUNDLE_SH=$BIN_DIR/tar-send.sh

workdir=${WORKSPACE:-/tmp}
proc=$$
out=out.${proc}.log

[ ! -x  $MKTMP_VIEW_SH ] &&  echo "** error: unable to execute script: $MKTMP_VIEW_SH" && exit 2
[ ! -x  $BUNDLE_SH ]     &&  echo "** error: unable to execute script: $BUNDLE_SH"     && exit 2

#trap 'echo "# cleaning up tmpfiles: $out" && rm -f "$out" >/dev/null 2>&1' 0
#trap "exit 2" 1 2 3 15

###################################################
# make ade view
#  either makes a new view with a unique name, or
#  just prints the view name tha would be created
do_mkview() {
  $MKTMP_VIEW_SH $@ -p oggadp -s main compare_git_p${proc}
}

copy_from_ade() {
  echo "========================================================================="
  printf "Copy from ADE:
      view=$view
      script=$BUNDLE_SH
      target file= $workdir/Adapter_${view}.tgz
      target dir: $target_dir\n\n"

  ade useview $view -exec "$BUNDLE_SH -l -F $workdir/Adapter_${view}.tgz Adapter"

  ls -l $p2file
  ls -l ${basen}.tgz

  [ -f  $p2file ] && ( mkdir -p $target_dir && cd $target_dir && tar xf ../${basen}.tgz ; )

  echo "==== Contents of git: ade/oggadp/Adapter => "
  ls -l ade/oggadp/Adapter

  echo "==== Contents of ade: $target_dir/Adapter => "
  ls -l $target_dir/Adapter

}

do_ade_diff() {
  echo "============== diff: ade/oggadp/Adapter $target_dir/Adapter =============="
  diff -r ade/oggadp/Adapter $target_dir/Adapter | tee $out
}

###################################################
# main
#

view_opts=$@
view=$( do_mkview $view_opts -v )      # get view name (only)
basen=Adapter_${view}
target_dir=${workdir}/${basen}
p2file=${workdir}/${basen}.tgz

# create a view. if "tip", apparently must refresh for recent changes (ade bug?)
do_mkview $view_opts -y
echo "$view" | grep "_tip$" >/dev/null && is_tip=true || is_tip=false
$is_tip \
  && echo "** warning: view is tip_default, first refreshing:  $view" \
  && ade useview $view -exec "ade refreshview"

copy_from_ade

do_ade_diff


