#!/bin/bash
#
# Apply a patch file to ADE files: creates an ADE txn, ADE check-out
# (or 'mkelem'), applies patch file.
#
# Examples:
#  $ diff-apply patch_file     # applies patch, runs ADE commands (interactive)
#  $ diff-apply -y patch_file  # applies patch, assumes "yes" to all questions
#  $ diff-apply -n patch_file  # dry-run (no changes)
#  $ diff-apply -h             # print help message (use this to see all options)
#
#  $ diff-apply -p patch_file  # if the script fails after all the ade commands,
#                              # and just just want to apply the patch (to ade)
#
# To update files in git (if ADE files are newer), assuming the patch file for
# git was created (patch__OLD.git...NEW.ade), apply using:
#  $ cd patch/oggadp_main/ade/oggadp
#  $ patch [ --dry-run ] -p1 < ../../../../patch__OLD_oggadp.git__NEW_{...}
#
# Notes:
#  Patch-files are generated from the diff-patch script, which compares the
#  files in ADE with the corresponding 'git' branch.

prog=${BASH_SOURCE[0]}

usage() { cat<<EOF
   Apply patch to ADE: (1) create ADE txn; (2) check-out files; (3) apply patch.

   Usage: ${prog} [-h|-n] [-t {target}] [-s {source}] patch_file
   Options:
     -d {desc} ade txn name, e.g: "foo_bug_1234" or "foo_bug_1234_5678"
               runs "ade begintrans" with "-bug 1234" or "-bug 1234,5678"
     -h        print help
     -n        dry-run for patch.
     -p        only apply patch, but does NOT run the ADE commands to
               check-out files. Assumes files are already checked-out.
     -y        assume 'y' for all  (ade, patch) questions and continue.

   Advanced options:
     -a        ONLY do ADE commands (create txn, check-out, mkelem) but SKIP applying the patch.
     -B        exclude binary files
     -s {dir}  source dir, original files, to copy binary files from
     -t {dir}  target dir to apply patch (to copy binary files to)

   Other options (mostly for debugging):
     -M   (ADE) don't check-in and merge the transaction
     -N   (ADE) turn ADE commands into no-op's (only displays what would be run).
          Not necessary when doing a dry-run (-n). See also -Q
     -Q   (ADE) disable ADE 'query' commands (listing files, etc).
          This makes things go faster, but it effectively breaks the script,
          since it is unknown if files are already in ADE, checked-out or not, etc.
     -v   verbose (opposite of -q )
     -q   quiet (opposite of -v)
     -Z   print ade description, label, exit (debugging)

   Patch is unified diff, "diff -ruN x/dir/file y/dir/file", applied
   using "patch -p1 < patch.diff (ignore top-level {x,y})"

   Environmental variables:
      Apply patch with additional options via PATCH_OPTS env var,
      $  PATCH_OPTS='--verbose ' $prog -n diff.patch
      The default options for patch are (these should not be reset):
      $  DEFAULT_PATCH_OPTS="--posix --backup-if-mismatch"
EOF
  return 0
}

#########################################################################
# Print given error message, and exit
# Usage: die [-u] [message]
#   -u  - print usage, otherwise just print error (if any) and exit
die() {
  local do_usage=false
  [ "$1" = "-u" ] && do_usage=true && shift
  [ $# -gt 0 ] && printf "** Error: $@\n\n" 1>&2
  $do_usage && usage
  exit 2
}


# remove the last word from the string, IFF there are multiple words
# e.g.,: "one two three four" => "one two three"
trunc() {
  if [ $# -gt 0 ]; then
      echo "$@" | sed 's/  *[^ ]* *$//'
  else
      sed 's/  *[^ ]* *$//'
  fi
}
#########################################################################
# Ask y/n and return true/false. If given "q", exits the script.
# If ask_assume_yes=true, return true, no user input required.
# May reply "a", which returns "y" for all remaining queries, if given
# the exact same question.
# Typical usage: ask "run build?" && make all || echo "bye"
#
ask() {
  $ask_assume_yes && return 0
  local ask_this_question=$(trunc "$@")
  local yn=y

  echo "# == (verify):  $@"
  if [ "$ask_last_question" = "$ask_this_question" ]; then
    $ask_assume_yes_temp && printf "# continuing to assume 'y'\n" && return 0
  else
    ask_assume_yes_temp=false
    ask_last_question=$ask_this_question
  fi

  read -n1 -p "# == continue? [y=yes|a=yes-to-all|n=no|q=quit] (y)" yn
  [ "$yn" = "q" ] && { printf "  ([$yn]...exiting...)\n"; exit 1; }
  [ "$yn" = "a" ] && { printf "  ([$yn]...assume 'y'...)\n" 1>&2; printf "\n"; ask_assume_yes_temp=true; return 0; }
  [ "$yn" = "" -o "$yn" = "y" ] && { printf "\n"; return 0; }
  printf "  ([$yn]...skip & continue...)\n"
  return 1
}


#########################################################################
# Run the given commands, unless "dry-run" is set. If not a dry-run,
# asks "y/n" before executing the command, unless ask_assume_yes=true
#
run() {
  local ret=1 tmp_sh=/tmp/run.$LOGNAME.$$.sh
  if $dry_run ; then
    printf "\n# (dry-run only! no changes will be made...)\n"
    echo "$@"
    return 0
  else
    echo
    cat /dev/null > $tmp_sh
    chmod a+rwx $tmp_sh
    echo "$@" > $tmp_sh
    if ask "$@" ; then
        cat $tmp_sh
        #set -x
        $tmp_sh
        ret=$?
        #set +x
        rm -f $tmp_sh
    fi
    return $ret
  fi
}

#########################################################################
# ADE "nop" (dry-run).
ade_nop() { echo "# (nop) ade $*"; }

#########################################################################
# Return true if file is under version control
is_versioned() { $ade_qry_prog ls -ld "$1" | grep -q '@@'; }

#########################################################################
# convert space/dash to "_", strip dupe's, remove trailing garbage
normalize(){
  sed  "s/  */_/g; s/--*/_/g; s/__*/_/g; s/^_//; s/_*$//"
}

#########################################################################.
# Return true if file is checked-out (may not work with all file types).
# Calls "is_versioned" to determine if the file is under version control.
#
is_checked_out() {
  local ret=1
  is_versioned && $ade_qry_prog ls -ld "$1" | grep -q CHECKEDOUT && ret=0
  $verbose && [ $ret -eq 0 ] && printf "#* file is already checked-out: $1\n"
  return $ret
}

#########################################################################
# Return true if file is considered "binary" by ADE (special ADE cmds are
# required for binary files.) Follows symlinks. Returns false if directory.
is_binary() {
  local is_bin
  is_bin=$(file -L "$1" | egrep -i -q ':.*text|:.*empty|:.*xml' && echo 'false' || echo 'maybe')
  [ "$is_bin" = "maybe" ] \
    && is_bin=$(file -L "$1" | egrep -i -q ':.*zip|:.*binary|:.*data' && echo 'true' || echo 'maybe')

  $verbose && printf "#* file is binary? $is_bin => $(file "$1")\n"
  [ "$is_bin" = "true" ]   # return true if file is definitely binary
}

#########################################################################
# Return true if file can be written to. May indicate that file is not
# checked-out, or is otherwise unprepared to be updated.
is_writable() {
  test -r "$1" && ! test -h "$1" test -w "$1"  # false if not writable OR is a symlink
}

#########################################################################
# return current view's label; if "-s", truncate to get series
ade_get_label() {
  local trunc=0 label="" file=$ADE_VIEW_ROOT/.labellog.emd
  [ $# -gt 0 -a "$1" = "-s" ] && shift && trunc=1
  [ -f $file ] && label=$( head $file | grep '^# label' | awk '{ print $NF }')
  [ $trunc -eq 1 -a ${#label} -gt 0 ] && label=$(echo "$label" | awk -F_ '{ print $1 "_" $2 "_" $3 }' )
  echo "$label"
  return 0
}

#########################################################################
# Return ade begintrans arguments: txn name, comment, options.
#  Given description like "fix_memleak_bug1234,5678", returns the txn name
#  comment AND the bug options at the end (so do NOT quote the return value)
#
get_begintrans_args () {
  local bug_opt owner desc bug_str bugs first_bug
  local stamp=$(date '+%Y%m%d')
  local label=$(ade_get_label -s)

  #set -x
  if [ $# -gt 0 -a "$@" != "" ]; then
    # strip bug info from $desc; $bugs is just 1234 or 1234,5678
    desc=$(echo "$@" | sed 's/bug[-_]*[0-9,]\{1,\}$//; s/[-_,. ]/_/g')  # everything except 'bug-123456'
    bugs=$(echo "$@" | grep 'bug' | sed 's/^.*\(bug[-_][-0-9,_]\)/\1/g; s/^bug//; s/[-_,]\{1,\}/,/g; s/^,//; s/,$//')
    first_bug=$(echo "$bugs" | sed 's/[-_,]\{1,\}.*//')
  else
    desc="fix"  # need a better default ade txn decription
  fi

  if [ "$desc" = "" ]; then
    desc=$(echo _"$ADE_VIEW_NAME" | sed "s/${LOGNAME}//; s/$label//I; s/_tip$//; s/_latest$//; s/bugfix//; s/bug_*//g; s/${first_bug:-xxxxx}//g" | normalize)
  else
    desc=$(echo "$desc" | normalize)
  fi

  [ "$bugs" != "" ] \
     && bug_opt="$bug_opt -bug $bugs" \
     && bug_str="bug-$bugs" \

  owner=$(whoami)
  desc=$(echo "$owner" "$desc" | normalize)

  echo "bug_str: $bug_str (bugs=$bugs / first=$first_bug)" 1>&2
  echo "owner: $owner" 1>&2
  echo "desc: $desc"   1>&2
  echo "date: $stamp"  1>&2
  #echo "$(echo "$stamp $bug_str $desc" | normalize | sed 's/,/_/g' ) $bug_opt"
  echo "$(echo "$bug_str $desc $stamp" | normalize | sed 's/,/_/g' ) -c \"$desc\" $bug_opt"
  #set +x
}


#########################################################################
# Begin ADE transaction, unless already in a transaction (just prints error).
ade_begin_transaction() {

  run $ade_mod_prog begintrans $(get_begintrans_args "$@") && return 0
  return 1
}

#########################################################################
# return true if we're currently in a ADE transaction
# note: we might be not even in an ADE view
in_transaction() {
  # ade ERROR: You must be in an ADE view to use this command.
  # ade ERROR: not in a transaction
  local ret=2
  $ade_qry_prog lsco 2>&1 | egrep -i "ade ERROR: not in a transaction|ade ERROR: You must be in an ADE view" 2>&1 >/dev/null && ret=1 || ret=0
  return $ret
}

#########################################################################
# Pass in file-path from patchfile; e.g., given "diff dir_a/dir/file dir_b/dir/file"
# pass in dir_a/dir/file.  The prefix is ignored (i.e., only uses "dir/file").
# Runs ADE commands from directory $target_dir (i.e., from 'dir_a').
# Uses last git commit message for ADE commit message when creating/checking out file.
#
checkout_or_create_file() {
  local a=$1 is_binary=false mkelem_opt="" src="" cmt_opt="-nc" cmt="" ret=0

  get_git_comment() {
    # commit msg formatting (w/ escaping) is tricky due to "ask"/"run"/"ade" wrappers.
    # note: perl-chomp converts multi-line commit msg, to one line, double-quoted
    cd ${source_dir} 1>/dev/null \
    && [ -f "$targ" ] \
    && git log -1 --pretty='%B(%an)(%h)' "$targ" \
          | egrep -v '^ *$' | sed "s:\":':g" |  sed "s:['()]:\\\&:g" \
          | perl -ne 'chomp;print $_," / "' | sed 's/ *\/ *$//' \
          | sed 's/^/"/; s/$/"/' \
    && cd - 1>/dev/null \
    && return 0 \
    || return 1
  }


  [ "$1" = "-b" ] && is_binary=true && shift && a=$1 && mkelem_opt="-binary"

  cd $target_dir 2>/dev/null 1>&2 || return 1

  [ "${a:0:1}" = "/" ] && a=${a:1}   # if a="/one/two", change to a="one/two"
  targ=${a#*/}                       # change a="one/two/three" => a="two/three"

  printf "# ====file:  $targ\n"
  if [ "$source_dir" != "" ] ; then
    src=${source_dir}/${targ}
    #printf "# ====source dir: $source_dir\n"
    [ -f "$src" ] \
      && printf "# ====source dir: $source_dir\n" \
      || printf "# ====source dir (file not found): $source_dir == src\n"

    #[ ! -f "$src" ] && printf "** Error: source file not found: $src\n" && return 1
  fi
  printf "# ====target dir:  $target_dir\n"

  cmt=$(get_git_comment) && [ ${#cmt} -gt 1 ] && cmt_opt="-c" || cmt_opt="-nc"

  if ! in_transaction ; then
    ade_begin_transaction "$ade_tx_desc" \
      || { $dry_run &&  printf "** Warning: No transaction started (dry-run)\n" || printf "** Error: ADE transaction not started.\n" ; }
  fi

  if [ -e "$targ" ]; then
      $ade_qry_prog ls -ld "$targ" | sed 's/^/# /'
      if is_versioned "$targ" ; then
        is_checked_out "$targ" || run $ade_mod_prog $ade_co_cmd $cmt_opt "$cmt" $targ
      else
        run $ade_mod_prog mkelem $mkelem_opt -recursive $cmt_opt "$cmt" $targ
      fi
  else  # target file does not exist
    targ_dir=$(dirname $targ)
    printf "#* file does not exist (pwd=$PWD): $targ\n"
    if [ ! -d  "$targ_dir" ] ; then
       printf "#* parent dir does not exist: dir=$targ_dir\n"
       run $ade_mod_prog mkdir -p $targ_dir
    fi
    if [ "$source_dir" != "" ] ; then
       [ -f "$src" ] && run cp -i $src $targ || printf "** Warning: source file does not exist: $src\n"
    else
      run touch $targ
    fi

    run $ade_mod_prog mkelem $mkelem_opt -recursive $cmt_opt "$cmt" $targ  # puts crap in empty file.
    [ -f $targ ] && [ "$is_binary" != "true" ] && cat /dev/null > $targ  # clear file again.
  fi
  printf "\n"
  cd -  2>/dev/null 1>&2
  return $ret
}

#########################################################################
# get the "old" file, to apply changes to. Might have to check it out
pre_patch() {
  local ret=0
  local tmp=0

  printf "\n# === Prepare the following files to be patched:\n"
  for x in $(egrep '^diff ' $patchfile | awk '{ print $(NF-1) }'); do
     printf "# $x\n"
  done || printf "## (end)\n" && printf "## (end)\n"

  if $do_binaries ; then
    printf "\n# === Binary files:\n"
    for x in $(egrep '^Binary files.*differ$' $patchfile | awk '{ print $3 }'); do
       printf "# $x\n"
    done || printf "## (end)\n" && printf "## (end)\n"
  fi
  printf "\n"

  # Contents of patch contain lines like:
  #   diff [many_opts]  a/dir1/dir2/text_file b/dir1/dir2/text_file
  #   Binary files a/dir1/dir2/binfile and b/dir1/dir2/binfile differ
  # Pass in the first file path (target directory is assumed)

  for x in $(egrep '^diff ' $patchfile | awk '{ print $(NF-1) }')
  do
     checkout_or_create_file "$x"
     tmp=$?
     if [ $tmp -ne 0 ]; then
       printf "** error returned($tmp): checkout_or_create_file $x\n"
       printf "** continuing to prepare, but won't apply patch.\n"
       ret=1
     fi
  done

  $do_binaries || { printf "**Warning: skipping binary files.\n" ; return $ret; }

  for x in $(egrep '^Binary files.*differ$' $patchfile | awk '{ print $3 }')
  do
     checkout_or_create_file -b "$x"
     tmp=$?
     if [ $tmp -ne 0 ]; then
       printf "** error returned($tmp): checkout_or_create_file $x\n"
       printf "** continuing to prepare, but won't apply patch.\n"
       ret=1
     fi
  done
  return $ret
}

#########################################################################
# for text:  run patch -p1 < patchfile
# for binary: copy newer binary files over out of date files
#
apply_patch() {
  cd $target_dir  2>/dev/null 1>&2
  printf "# =========== $PWD ====\n"
  ask "patch $PATCH_OPTS -p1  < $patchfile" \
     && patch $PATCH_OPTS -p1 < $patchfile
  cd -  2>/dev/null 1>&2
}

apply_patch_binaries() {
  local x y tmpfile tmp_targ
  #cd $target_dir  2>/dev/null 1>&2
  #printf "# =========== $PWD ====\n"
  egrep '^Binary files.*differ$' $patchfile >/dev/null \
    && ask "update binary files?" \
    && for x in $(egrep '^Binary files.*differ$' $patchfile | awk '{ print $5 }')
      do
         tmpfile=${x#*/}
         tmp_targ=${target_dir}/$tmpfile
         [ -f $x ] || echo "** warning: source file does not exist: $x"
         [ -f $tmp_targ ] || echo "** warning: target file does not exist: $tmp_targ"
         echo "updating: source: $x "
         echo "updating: target: $tmp_targ"
         ask "copy $x $tmp_targ ?" && cp -i $x $tmp_targ || echo "not updating: $tmp_targ"
      done

  return $ret
}

#########################################################################
#  try to verify that we have a unified diff patch file
is_patchfile() {
  local p1 p2 tmp_p
  p1=$patchfile
  p2=$(readlink -f $p1)

  if [ ! -f "$p1" -o ! -f "$p2" ]; then
    printf "** Error: patch file not found: $p1\n" 1>&2
    [ "$p1" != "$p2" ] && printf "** Full path to file: $p2\n" 1>&2
    return 1
  fi

  if [ -s $p1 ] ; then
    tmp_p=$(head -10  "$p1" | sed -n '/dif/,$'p | head -3 | cut -c1-4 | tr '\12' ' ' | sed 's/  *//g')
    if [ "$tmp_p" != "diff---+++"  ] ; then
      printf "** Warning: patch file doesn't appear to be a unified diff: $p1 ($tmp_p)\n"
      ask "continue with patch?" && return 0 || return 2
    fi
  fi
  return 0
}

#########################################################################
# Options
#########################################################################

target_dir="../../oggadp"      # target ADE files (files to checkout & patch)
source_dir="oggadp.git"        # original files (e.g, if binaries need to be copied)
ade_mod_prog=ade               # ade modify state, disabled if dry_run=true
ade_qry_prog=ade               # ade queries & displaying info

ade_co_cmd="co -no_update_hdr" # avoid modifying file header on checkout
ade_tx_desc=""                 # txn desc ("bug_1234_5678" =ade=> "-bug 1234,5678")

do_version_control=true        # optionally disable ADE commands
do_ade_bs=true                 # do all the mergereq + ade beginmerge + mergetrans + endmerge bs (all specific to
                               #    oggadp, since it only has the ade/bugdb process-"lite" enabled. oggcore has more
                               #    bugdb/mergereq processes/features/workflow enabled than oggadp)
mergereq_user=mike.nielsen     # mergereq username (manager)
do_patch=true                  # optionally disable patch
dry_run=false                  # totally innocent pre-run check
verbose=true                   # prints extra info
ask_assume_yes=false           # if you don't want to type "y" alot (after dry-run)
ask_assume_yes_temp=false      # temporarily assume 'y', until a different question is asked
ask_last_question="xxxx"       # last question asked, when asking "continue? [y|n|a]"

do_binaries=true
opt=""
: ${DEFAULT_PATCH_OPTS:="--posix --backup-if-mismatch"}
PATCH_OPTS="${DEFAULT_PATCH_OPTS} ${PATCH_OPTS}"

#echo "===$@"
#printf "test\n"
OPTIND=1

while getopts d:hnpqs:t:vyBMNPQU:VZ opt ; do
  case "$opt" in
  d) ade_tx_desc=${OPTARG} ;;
  h) die -u ;;
  n) dry_run=true
     PATCH_OPTS="$PATCH_OPTS --dry-run"
     ;;
  q) verbose=false ;;
  s) source_dir=${OPTARG} ;;
  t) target_dir=${OPTARG} ;;
  v) verbose=true ;;
  y) ask_assume_yes=true ;;

  B) do_binaries=false ;;
  M) do_ade_bs=false;;  # disable ade commit/merge-request/merge-begin/merge-trans/merge-wtf/merge-end/bs
  U) mergereq_user=${OPTARG};;  # the "manager" for the mergereq bs
  N) ade_mod_prog=ade_nop ;;
  Q) ade_qry_prog=ade_nop ;;

  a) do_patch=false
     do_version_control=true
     ;;

  p) do_patch=true
     do_version_control=false
     ;;

  Z) shift
     echo "===================================="
     echo "txn desc: $(get_begintrans_args $@)"
     echo "===================================="
     echo "label: $(ade_get_label -s)"
     echo "===================================="
     exit 2
     ;;
  *) die -u "unknown option: $@\n\n" ;;
  esac
done; shift $((OPTIND-1)); OPTIND=1


# Error checking
[ $# -eq 0 ] && die -u "expecting patchfile"
for patchfile ; do
  is_patchfile $patchfile || exit 2
done

# apply all given patches
for patchfile ; do
  patchfile_orig=$patchfile
  ## get abs path to patchfile, since we chdir to run 'patch'
  [ ! -s $patchfile ] && printf "\n** Warning: patch file is empty (ignoring):  $patchfile\n\n" && continue
  [ ${patchfile:0:1} != "/" ] && patchfile=$(readlink -f $patchfile)
  [  ! -d $target_dir ] && die "target directory to apply patch file does not exist: $target_dir"

  ## if fetch binary files (use abs path, since chdir to target_dir to patch)
  if [ "$source_dir" != "" ]; then
    [ ! -d "$source_dir" ] && die "source directory not found: $source_dir"
    source_dir=$(readlink -f $source_dir)
    [ ! -d "$source_dir" ] && die "source directory not found: $source_dir"
  fi

  printf "#########################################################################\n"
  printf  "# apply patch (ignore top-level dir (patch -p1)): $patchfile_orig\n"
  printf  "# target directory (running 'patch' here):  $target_dir\n"
  [ "$source_dir" != "" ] && printf  "# source directory (copy files from here):  $source_dir\n"
  printf "#########################################################################\n\n"

  if $do_version_control ; then
    if pre_patch ; then
      if $do_patch ; then
        apply_patch
        $do_binaries && apply_patch_binaries
      fi

      if $do_ade_bs; then
        # notes:
        # * the 'invalid_xml' seems to no longer exist as an option? ade mergetrans -force_invalid_xml
        # * optionally disable ade commit/merge-request/merge-begin/merge-trans/merge-wtf/merge-end
        # * if mergereq is enabled, it'll be run; if it's not, it'll print an error and continue
        #     v1:  /usr/local/bin/mergereq -y --manager mike.nielsen --platform LINUX # --other --bug {num}
        #     v2:  /usr/local/bin/mergereq -y -m mike.nielsen -r mike.nielsen -e true
        #     v3:  printf '5\n6\nrunning mergereq\n'  | /usr/local/bin/mergereq --resend --db-only -m mike.nielsen -r mike.nielsen -e true
        #     v4:  printf '5\n6\nrunning mergereq\n'  | /usr/local/bin/mergereq --resend -y -m mike.nielsen -r mike.nielsen -e true
        run ade ciall && printf "** Success: checked-in all files\n" \
          || { printf "** Error: unable to check-in all files"; exit 2; }

        # fails if not enabled, or (hopefully) runs and answers the questions in the right order
        #printf '5\n6\nrunning mergereq\n' | /usr/local/bin/mergereq --resend -y -m  $mergereq_user -r $mergereq_user -e true
        /usr/local/bin/mergereq --resend -y -m  $mergereq_user -r $mergereq_user -e true

        run ade beginmerge \
           && run ade mergetrans \
           && run ade endmerge
      else
        printf "** Patch applied, but files not checked-in, merge-req's, pre-merged, merge-merged, post-merged\n" 1>&2
        printf "** To finish applying the patch, run: \n" 1>&2
        printf "**    ade ciall \n" 1>&2
        printf "**    /usr/local/bin/mergereq -y -m mike.nielsen -r mike.nielsen -e true\n" 1>&2
        printf "**    ade beginmerge && ade mergetrans && ade endmerge\n" 1>&2
      fi
    else
      printf "** Unable to prepare ADE, won't apply patch. After correcting any errors,\n" 1>&2
      printf "** re-apply patch with option '-p'. Look for minor error or warnings, \n" 1>&2
      printf "** missing copyright, ADE warnings, reports 'continuing... but won't apply patch'.\n\n" 1>&2

    fi
  elif $do_patch ; then
    printf "** skipping ADE commands, only apply patch.\n" 1>&2
    apply_patch
    $do_binaries && apply_patch_binaries
  fi
done

