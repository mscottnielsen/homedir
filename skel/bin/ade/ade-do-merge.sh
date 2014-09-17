#!/bin/bash
#
# (A bit of a hack, not a generically useful script.)
#
# Merge git changes into ADE.
#
# Expected to be run from view.
# Script does cd to this directory => $ADE_VIEW_ROOT/oggadp
# so that the Adapter subdirectory is in PWD.
#
#


#########################################################################
# set env vars...
adp=Adapter
git_dir=/home/msnielse/git-wk/code-co-oggadp/oggadp/ade/oggadp

# script CD's to this directory
ade_dir=$ADE_VIEW_ROOT/oggadp

[ -z $ADE_VIEW_ROOT ] && echo "** error: not in a view" && exit 2
[ ! -d $ade_dir ] && echo "** error: directory doesn't exist: $ade_dir" && exit 2

ade_adp_dir=${ade_dir}/$adp
git_adp_dir=${git_dir}/$adp

########## DEBUG: set DO_RUN to 'echo' to disable actions
#DO_RUN=echo
ADE="$DO_RUN ade"
COPY="$DO_RUN cp -i"
tmp_list=/tmp/foo99-list.sh
tmp_script=/tmp/foo99-copy.sh


#########################################################################
# get options

tx_desc="fix"
commit_msg=""
OPTIND=1

while getopts t:m: opt
do
  case "$opt" in
  t)
    tx_desc=${OPTARG} &&  printf "setting ade tx name: $tx_desc\n"
    ;;
  m)
   commit_msg=${OPTARG} &&  printf "setting ade commit msg: \"$commit_msg\"\n"
    ;;
  *)
    printf "** error: unknown option given\n"
  esac
done; shift $((OPTIND-1)); OPTIND=1

ts=$(date '+%Y-%m-%d_%H%M')
trans_name=$(echo "${tx_desc}_${ts}" | sed 's/ /_/g')

#########################################################################
# clean up from previous run(s)
[ -f $tmp_script ] \
  && rm $tmp_script \
  && [ -f $tmp_script ] \
  && echo "**error: unable to remove $tmp_script" \
  && exit 2


#########################################################################
# ask y/n and return true/false
ask() {
  yn=y
  echo "====== (verify)  $@" \
    && sleep 1 \
    && read -n1 -p "====== continue? [y|n|q] (y)" yn \
    && echo

  [ "$yn" = "q" ] && printf "      (...exiting...)\n\n" && exit 2
  [ "$yn" != "y" ] && printf "       (...skipping & continuing...)\n\n" && return 2
  printf "\n"

  return 0
}

#########################################################################
# recursive diff, ignoring certain files and dirs.
diffr () {
  echo "### diff -r --exclude=\".svn\" --exclude=\".git\" --exclude=\".ade_path\" --exclude=\"*.gz\" --exclude=\"*.tar\" --exclude=\"*.zip\" --exclude=\"*.o\" --exclude=\"*#[0-9]\" $@"
  diff -r --exclude=".svn" --exclude=".git" --exclude=".ade_path" --exclude="*.gz" --exclude="*.tar" --exclude="*.zip" --exclude="*.o" --exclude="*#[0-9]" $@
}


#########################################################################
# run mergereq
do_mergereq() {
  if test -z "$DO_RUN"
  then
      echo "(running) /usr/local/bin/mergereq -y --platform LINUX"
      /usr/local/bin/mergereq -y --platform LINUX
  else
     echo "(not running) /usr/local/bin/mergereq -y --platform LINUX"
  fi
}

#########################################################################
# working dir
cd $ade_dir

#########################################################################

# get tmp file with files that are changed
diffr -u -q $git_adp_dir $adp | tee $tmp_list

# display list of files that have changed
all_files=$( cat $tmp_list | grep ^Files.*differ$ | awk '{ print $4 }' )
printf "\n====\n$all_files\n====\n"

# begin an ADE transaction?
ask "begintrans:  $trans_name " && $ADE begintrans $trans_name

# check-out all files that have changed?  give option to check-out specific files one-by-one.
ask "checkout all files at once? " && checkout_all=1 ||  checkout_all=0
[ $checkout_all -eq 1 ]  && $ADE co -c "$commit_msg" $all_files

# could allow option unique messagse for each
[ $checkout_all -eq 0 ]  && for x in $all_files
do
  ls -l $x
  # this will ask for comment for each file...
  ask "checkout file: $x (message=$commit_msg)" && $ADE co -c "$commit_msg" $x \
    || ( ask "checkout file: $x (will prompt for message)" && $ADE co $x )
done


# gen script to copy git diff's over ADE files
echo "==== generating script:  $tmp_script"
printf '#!/bin/bash\n\n' > $tmp_script
printf "COPY=\"$COPY\"\n" | tee -a $tmp_script
cat $tmp_list | grep ^Files.*differ$ | awk '{ print "$COPY ", $2,  $4 }'  | tee -a $tmp_script
[ -f $tmp_script ] && chmod a+x $tmp_script

ask "copy files from git to ADE (run script $tmp_script)?" && /bin/bash -x $tmp_script

ask "check-in all files?" && $ADE ci -all

ask "run mergereq?"      && do_mergereq
ask "begin merge?"       && $ADE beginmerge
ask "merge transaction?" && $ADE mergetrans
ask "end merge?"         && $ADE endmerge

