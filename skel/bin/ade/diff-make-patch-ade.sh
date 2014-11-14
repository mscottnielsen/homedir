#!/bin/bash
#  Compare files in ADE and git and create a patch (unified diff).
#  Patch file for ADE created by default (i.e., files in git are newer).
#  See 'usage'.


PROG_PATH=${BASH_SOURCE[0]}      # this script's name
PROG_NAME=${PROG_PATH##*/}       # basename of script (strip path)
PROG_DIR="$(cd "$(dirname "${PROG_PATH:-$PWD}")" 2>/dev/null 1>&2 && pwd)"

##############################################################################
usage() { cat<<EOF
 Compare files in ADE and git and create a patch (unified diff).
 Patch file for ADE created by default (i.e., files in git are newer).

 Usage:  $PROG_NAME  [ -p | -a | -g | -A | -G {dir} | -w {dir} ]  [proj]
 Options:
   [proj] - dirs to diff, e.g.: oggadp/{proj}
   -A        do not update ADE source (compare to -G {dir})
   -a        create patch for ADE (ADE is out-of-date)
   -g        create patch for Git (Git is out-of-date)
   -h        print help/usage
   -p        recreate patch only - do not refresh ADE or git
   -w {dir}  use given work directory; by default, \$ADE_VIEW_ROOT/{proj}/patch

 Advanced options:
   -b {br}   git clone branch {br}. By default branch name is inferred from view
   -t {tag}  git checkout given tag (eg, "v11.2"). By default, no tag is assumed.

   -G {dir}  do not update Git source, use the given git repo: {dir}/.git and {dir}/ade exist
   -P {proj} use the given ADE project under \$ADE_VIEW_ROOT, e.g: {oggadp, oggcore,...}

 A patch is created by:
  (1) copy ADE source into pwd (following symbolic links);
  (2) git clone corresponding branch into pwd;
  (3) create symlinks to the ADE and git source directories,
      {proj}.git and {proj}.ade (eg, Adapter.git, Adapter.ade)
  (4) diff -ruN {proj}.ade {proj}.git

 Examples (see also: 'diff-apply' script):
   Create and apply patch to ADE:
      $ ./$PROG_NAME
      $ ./diff-apply.sh {patch_file}
   Create and apply patch to git:
      $ ./$PROG_NAME -g
      $ cd oggadp_dev-main/ade/oggadp  # same dir as 'Adapter','build'
      $ patch -p1 < ../../../patch_file

 See also:
     tar-send.sh - used to create tar to copy source from ADE
     diff-apply.sh - to apply the patch to ADE
EOF
  return 0
}

##############################################################################
# variables

# diff options to create a patch file.
# * (-u) unified diff's; (-N) "new" files are lines added to an empty file.
# * (don't use '-a'; it's bad if there are binary files)
diff_opts="-N -u"
exclude=
exclude_javabin="--exclude=\"*.jar\" --exclude=\"*/ant-latest/*\" --exclude=\"*/.settings\""

# script to copy ADE source via tar, following symlinks.
DEFAULT_TAR_SCRIPT=${PROG_DIR}/tar-send.sh
TAR_SCRIPT=${TAR_SCRIPT:-$DEFAULT_TAR_SCRIPT}
[ ! -x "$TAR_SCRIPT" ] \
  && printf "\n** warning: can't execute TAR_SCRIPT=${TAR_SCRIPT}\n" \
  && TAR_SCRIPT=$HOME/bin/ade/tar-send.sh
[ ! -x "$TAR_SCRIPT" ] \
  && printf "\n** error: can't execute TAR_SCRIPT=${TAR_SCRIPT} (default=$DEFAULT_TAR_SCRIPT)\n" \
  && exit 2

##############################################################################
# err msg and quit
fail() {
 echo "** error: $@ " 1>&2
 exit 2
}

##############################################################################
# Usage:  diffr {diff options} old_dir1 new_dir2
#  Create a patch, given two dirs in pwd, not subdirectories.
#  Compares just source code; ignores binaries, backups, VCS files, etc.
#
# Notes:
#  * for a useful patch, the two dir's are relative paths in pwd *without* subdirectories.
#  * it's ok to pass in diff options, but $diff_opts is already passed in.
#
diffr () {
  [ $# -lt 2 ] && echo "** error: 'diffr' expecting at least two args (Given: ($#): $@)" && return 2
  for arg
  do
    if [ ${arg:0:1} != "-" ]; then
      [ ! -d "$arg/" ] \
           && echo "** error: expecting directory. Given: $arg" && return 2
      #echo "$arg" | egrep -q '/|^\.' \
      #     && echo "** error: 'diffr' paths cannot have subdirectories (Given: $arg)" && return 2
    fi
  done

  #set -x
  diff -r  $diff_opts \
       --exclude="*~" \
       --exclude="*#*" \
       --exclude="CVS" \
       --exclude=".svn" \
       --exclude=".git" \
       --exclude=".ade_path" \
       --exclude="*.zip*" \
       --exclude="*.gz" \
       --exclude="*.tar" \
       --exclude="*.tar.gz" \
       --exclude="*.tgz" \
       --exclude="*.o" \
       --exclude="*.a" \
       --exclude="*.so" \
       --exclude="*.dll" \
       --exclude="test_driver" \
       --exclude="*.jar" \
       --exclude=".classpath" \
       --exclude="*.class" \
       --exclude=".project" \
       --exclude=".settings" \
       --exclude="ant-latest" \
       $@
   #set +x

   #   --exclude="test_driver" $exclude_javabin  $exclude \
}


##############################################################################
# e.g., print OGGADP_MAIN_PLATFORMS_121012.0700 or OGGADP_11.2.1.0.0_PLATFORMS_{timestamp}
get_ade_label() {
  local name=$( ade catcs | awk '/^VIEW_LABEL/ { print $NF }' | sed 's/  *//g' )
  [ "$name" = "" ] && echo "OGGADP_MAIN_PLATFORMS" || echo "$name"
}

# print OGGADP_MAIN_PLATFORMS or OGGADP_11.2.1.0.0_PLATFORMS
# but if given "-g" then convert OGGADP_11.1.1.0_PLATFORMS => OGGADP_11.1.1.0.0_PLATFORMS
# to convert ade label to git branch.
get_ade_series() {
  local name=$( get_ade_label | awk -F_ '{ print $1 "_" $2 "_" $3 }' | sed 's/ *//g')
  # convert OGGADP_11.1.1.0_PLATFORMS => OGGADP_11.1.1.0.0_PLATFORMS (add digit)
  # (git branches are consistent, ADE series are not)
  name=$(echo "$name" | sed 's/\(OGGADP_[12][12]\.[0-9].[0-9].[0-9]\)\(_PLATFORMS\)/\1.0\2/')
  [ "$name" = "" ] && echo "OGGADP_MAIN_PLATFORMS" || echo "$name"
}

##############################################################################
# run inside "patch" dir; first "cd" to ade dir to tar up ade source dir.
# untar in patch dir, using that for the 'diff'.
#
copy_ade_source() {
  local dirs=$@
  local fname=Adp__${ADE_VIEW_NAME}__$(date '+%Y-%m-%d_%H_%M').tgz
  local dname=$(basename $fname .tgz)

  cd $ADE_PROJ_DIR && $TAR_SCRIPT -F $fname $dirs \
    || fail "unable to create tarball from ADE source: $dirs"

  [ -d $PATCH_DIR -a -f $fname ] \
    && mv -i $fname $PATCH_DIR/ \
    && cd $PATCH_DIR \
    && [ -f $fname ] \
    || fail "cannot move ADE tgz into patch dir: file=\"$fname\" to directory=\"$PATCH_DIR\""

  # create a subdir w/ same name as the tar.gz, and extracts the file inside
  ( mkdir $dname \
    && cd $dname \
    && tar xzf ../$fname \
    || fail "unable to mkdir and extract source tarball (dir=$dname, file=$fname)" ) \
    || return 2

  [ -h $ADE_PROJ_DIR_LN -o -e $ADE_PROJ_DIR_LN ] && rm $ADE_PROJ_DIR_LN

  printf "** updating $ADE_PROJ_DIR_LN => $dname\n\n"
  ln -is $dname $ADE_PROJ_DIR_LN || fail "cannot create symlink ${dname} -> $ADE_PROJ_DIR_LN"
  test -e $ADE_PROJ_DIR_LN
  return
}


##############################################################################
# if given ade_dir and git_dir, then ade is new, git is out of date;
#   create a patch that can be applied to git to bring it into sync.
#
# if given git_dir followed by ade_dir, then git is old, and ade is new;
#   create a patch that could be applied to ADE to bring it into sync.
#   (note: patch can't literally be "applied", since ade files need to be
#   checked-out, a txn created, changes "merged", mergereq created, etc).
#
mk_patch () {
  [ $# -lt 4 ] && fail "Missing arguments. Usage: mk_patch {patch_dir} {old_dir} {new_dir} {compare_dir} (Given: ($#) $@)"
  local patch_dir=$1 old_path=$2 new_path=$3 comp_dir=$4
  local old_dir=$(basename "$old_path") new_dir=$(basename "$new_path")

  for d in $patch_dir {$old_path,$new_path}/$comp_dir ; do
    [ ! -d "$d" ] && fail "directory does not exist: $d"
  done

  local p=patch__OLD_${old_dir}_${comp_dir}__NEW_${new_dir}_${comp_dir}__$SFX
  echo "========================== $p ========"
  ( cd $patch_dir &&  diffr $old_dir/$comp_dir $new_dir/$comp_dir > $p )

  test -s $p || { echo "## No difference: $comp_dir"; rm "$p" ; return 0; }

  # see extended 'exclude' above to see what to strip from output summary
  egrep '^Bin|^dif|^Only' $p | sed 's/--exclude.*-exclude=ant-latest/-exclude=.../'
  return 0
}

##############################################################################
# git clone the given branch
clone_git_repo() {
  local br=$1 tag=$2

  [ $# -eq 0 -o "$br" = "" ] \
     && printf "** error: git clone expects branch (given branch=\"$br\", tag=\"$tag\")\n" \
     && return 2

  printf "== cloning repo, branch=\"$br\", tag=\"$tag\"\n"
  git ls-remote $GIT_REMOTE  | grep "refs/heads/$br" || return 2
  git clone -b "$br" $GIT_REMOTE
  ( cd oggadp_dev-main
    git fetch --tags
    [ "$tag" != "" ] \
        && printf "== checkout tag=\"$tag\"\n" \
        && git checkout tags/$tag \
        || printf "== not checking out a tag\n"
   )
}

##############################################################################
# Create a symlink {proj}.git to an existing git working dir.
# If link exists, leave it. If git repo exists, but no link, then create link.
# Verify link exists, else exit.
create_link_to_git() {
  local link_name=$(basename $GIT_PROJ_DIR_LN)
  #set -x
  # remove link if broken
  [ -h $GIT_PROJ_DIR_LN -a ! -e $GIT_PROJ_DIR_LN ] && rm $GIT_PROJ_DIR_LN

  if [ -d $GIT_PROJ_DIR -a ! -h $GIT_PROJ_DIR_LN ]; then
    ( cd $PATCH_DIR \
        && ln -is $GIT_PROJ_DIR $link_name \
        && printf "** created link from $link_name => $GIT_PROJ_DIR\n" \
        || fail "unable to create link: $link_name => $GIT_PROJ_DIR" ) \
        || return 2
  fi
  ( cd $GIT_PROJ_DIR_LN \
     || fail "git project directory does not exist: $GIT_PROJ_DIR" ) \
     || return 2
  #set +x
  return 0
}

##############################################################################
# main...
##############################################################################
PROJ=oggadp
GIT_BRANCH=
GIT_TAG=

do_usage_and_exit=false
do_clone_git=false          # don't clone by default (unless it's missing)
do_copy_ade_src=true        # if ade has been updated, get a new copy

# which patch files to generate
do_patch_ade=true           # patch just ade by default
do_patch_git=true           # optionally gen patch for git (disables ade patch)
setopt_patch_ade=false      # gen patch for both, only if both options are set
setopt_patch_git=false

OPTIND=1
while getopts aAb:e:ghG:P:pt:w: opt ; do
  case "$opt" in
    a) # create patch for ade (assume git is newer) [default]
       setopt_patch_ade=true
       do_patch_git=false
       do_patch_ade=true
       ;;
    A) # use existing ADE copied src
       do_copy_ade_src=false
       ;;
    b) # given the specific branch in git to sync with
       do_clone_git=true
       GIT_BRANCH=${OPTARG}
       ;;
    e) exclude="$exclude --exclude=\"${OPTARG}\" "
       ;;
    g) # create a reverse patch: patch for git (assume ade is newer)
       setopt_patch_git=true
       do_patch_git=true
       do_patch_ade=false
       ;;
    G) # use existing git repo given
       do_clone_git=false
       GIT_PROJ_DIR=${OPTARG}
       [ ! -d $GIT_PROJ_DIR ] && do_usage_and_exit=true && printf "** Error: git project directory does not exist: $GIT_PROJ_DIR\n"
       [ ! -d $GIT_PROJ_DIR/.git ] && do_usage_and_exit=true && printf "** Error: git project directory is not a valid git repository: $GIT_PROJ_DIR\n"
       [ ! -d $GIT_PROJ_DIR/ade ]  && do_usage_and_exit=true && printf "** Error: git project directory does not contain an ADE project: $GIT_PROJ_DIR/ade\n"
       ;;
    P) # proj dir under ADE_VIEW_ROOT {oggadp, oggcore,...}
       PROJ=${OPTARG}
       ;;
    p) # just regenerate patch(es), do not refresh ADE / git
       do_copy_ade_src=false
       do_clone_git=false
       ;;
    t) # given the specific git tag
       do_clone_git=true
       GIT_TAG=${OPTARG}
       ;;
    w) # working directory (created patch files, git clone, ade src copy)
       PATCH_DIR=${OPTARG}
       ;;
    h | *) do_usage_and_exit=true
       ;;
  esac
done; shift $((OPTIND-1)); OPTIND=1

# dirs under PROJ => {view}/oggadp/* and {git}/ade/oggadp/*
[ $# -gt 0 ] && DIRS="$@" || DIRS=Adapter,build
DIRS=$(echo "$DIRS" | sed 's/,/ /g')

ADE_PROJ_DIR=$ADE_VIEW_ROOT/${PROJ}            # /ade/$view/oggadp/{Adapter,build}
PATCH_DIR=${PATCH_DIR:-"$ADE_PROJ_DIR/patch"}  # temp working directory
ADE_PROJ_DIR_LN=$PATCH_DIR/${PROJ}.ade         # link to ADE_PROJ_DIR
GIT_PROJ_DIR_LN=$PATCH_DIR/${PROJ}.git         # link to GIT_PROJ_DIR
GIT_PROJ_DIR=${GIT_PROJ_DIR:-"$PATCH_DIR/oggadp_dev-main"}/ade/$PROJ
#GIT_REMOTE="git@ipubs.us.oracle.com:oggadp_main"
GIT_REMOTE="ssh://mike.nielsen%40oracle.com@alm.oraclecorp.com:2222/oggadp_dev-main/oggadp_dev-main.git"

ADE_SERIES=$(get_ade_series -g)
SFX=${ADE_SERIES}                              # suffix for patch file (eg, ade label)
[ "$GIT_BRANCH" = "" ] && GIT_BRANCH=ade-${ADE_SERIES}   # branch to checkout

$do_usage_and_exit && usage && exit 2
$setopt_patch_ade && $setopt_patch_git && { do_patch_git=true; do_patch_ade=true; }

# either git project dir or symlink should exist
[ -d $GIT_PROJ_DIR -o -e $GIT_PROJ_DIR_LN ] || do_clone_git=true

if $do_clone_git ; then
  clone_git_repo "$GIT_BRANCH" "$GIT_TAG" || exit 2
  [ -h $GIT_PROJ_DIR_LN ] && rm $GIT_PROJ_DIR_LN
fi

create_link_to_git || { printf "** error, unable to create link to git."; exit 2; }

$do_copy_ade_src && { copy_ade_source $DIRS || exit 2; }

for dir in $DIRS ; do
  [ ! -d $ADE_PROJ_DIR/$dir ] \
     && fail "Directory does not exist: \"$dir\"  (in directory: $ADE_PROJ_DIR)"

  # mk_patch: patch dir, src/target dirs, dir to diff
  [ "$do_patch_git" = "true" ] && mk_patch $PATCH_DIR $GIT_PROJ_DIR_LN $ADE_PROJ_DIR_LN $dir
  [ "$do_patch_ade" = "true" ] && mk_patch $PATCH_DIR $ADE_PROJ_DIR_LN $GIT_PROJ_DIR_LN $dir
done

