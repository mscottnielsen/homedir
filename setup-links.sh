#!/bin/bash
#
## Create symlinks from $HOME directory to individual dot-files in this directory.
## The dot-files are intended mostly for bash, but other shells could be supported.
## Includes 'bin' directory, bash competion scripts, various env files.
##
## Run this script from the directory where the script is located.
##
## If there are conflicts with existing dot-files in your home directory: they may
## be overwritten (-c), backed-up with timestamps (default), or left unchanged (-p).
##

usage() { cat<<EOF
    Usage: setup-links.sh [-c|-g|-h|-i|-p] [-d {dir}]
      -c  - clobber: overwrite (no timestamped backups) conflicting files in \$HOME
      -d {dir} - create links in {dir} rather than \$HOME
      -g  - update only .gitconfig (nothing else), first creating ~/.gitconfig.sample
      -h  - print usage/help info
      -i  - ask (mv -i, rm -i) before removing/moving files in \$HOME
      -p  - preserve: do not overwrite or move existing files in \$HOME

    By default, existing files are backed up with a timestamped suffix: e.g., {file}.$(date '+%Y-%b-%d_%H-%M').
    If files aren't backed-up (-c/-i), they will be moved to '{file}.bak'
    The ~/.gitconfig file isn't created as a symlink, since it must be customized with a name and email.
EOF
  return 0
}

# Create a new ~/.gitconfig.sample, with existing name/email in ~/.gitconfig
# Does not create a new ~/.gitconfig if one doesn't currently exist
do_install_gitconfig() {
  local config="$HOME/.gitconfig"
  local temp_config="$HOME/.gitconfig.sample"
  local new_config="${PWD}/$dir/.gitconfig.sample"
  local current_config
  local user_name user_email
  local default_name default_email

  [ -h $temp_config -o ! -s $temp_config ] && rm -f $temp_config 2>/dev/null
  [ -f $temp_config ] && cp $temp_config ${temp_config}.old || cp $new_config $temp_config
  [ -e $config ] && current_config=$config || current_config=$temp_config

  # must match skel/.gitconfig.sample
  default_name="#name = Default Name"
  default_email="#email = no_email@example.com"

  # existing name/email in .gitconfig
  user_name=$(  { egrep "^[ 	]*name *=.*"  $current_config  || printf "${default_name}"  ; } | head -1 | sed 's/^[ 	]*//' )
  user_email=$( { egrep "^[ 	]*email *=.*" $current_config  || printf "${default_email}" ; } | head -1 | sed 's/^[ 	]*//')

  printf "** From existing: $current_config =create=> $temp_config\n"
  printf "**   name  => \"$user_name\" / email = \"$user_email\"\n"

  cat $new_config | \
    sed "s/$default_name/$user_name/" | \
    sed "s/$default_email/$user_email/" > $temp_config

  if [ ! -f $config ]; then
    printf "** Sample gitconfig created:  $temp_config\n"
    printf "** Update with your name & email and copy to: ~/.gitconfig\n"
  else
    printf "*************************************************************\n"
    printf "** diff $temp_config $config\n\n"
    diff -s $temp_config $config || {
      printf "\n** Overwrite existing \"$config\" with new \"$temp_config\"?\n"
      cp -i $temp_config $config
    }
  fi
}



# for all files in 'skel', move old original file in $HOME out of the
# way if there's a conflict, and create a symlink from $HOME to this 'skel'
link_all_files() {
  local x h
  for x in $PWD/$dir/.??* $PWD/$dir/* $PWD/../servers/host_env
  do
    [ ! -e $x ] && continue
    h=$home/$(basename $x)
    if [ ! -e $h ]; then
      # create link from ~/.dotfile to $pwd
      printf "creating link: ln -s $x $h\n"
      ln -s $x $h
    elif ! $overwrite ;  then
      printf "file exists (unchanged): $(ls -ld $h | awk '{ print $NF }')\n"
    else
      $do_backup && bak="${h}.$(date '+%Y-%b-%d_%H-%M')" || bak="${h}.bak"
      printf " ** moving => $(ls -ld $h)\n **     to => ${bak}\n"
      [ -e "$bak" ] && $remove -r "$bak"
      $move "$h" "$bak"
      printf "creating link: ln -s $x $h\n"
      ln -s $x $h
    fi
  done
}


move="mv"
remove="rm"
overwrite=true
home=$HOME
do_backup=true
git_conf_only=false

while getopts cd:ghip opt
do
  case "$opt" in
  c) do_backup=false
     ;;
  d) home=${OPTARG}
     printf "** using HOME=$home\n"
     ;;
  g) git_conf_only=true
     ;;
  i) overwrite=true
     move="mv -i" ;  remove="rm -i"
     ;;
  p) overwrite=false
     move="mv -i" ; remove="rm -i"
     ;;
  h | *) usage; exit 2
     ;;
  esac
done; shift $((OPTIND-1)); OPTIND=1

# historically, was 'homedir' in svn; now is 'skel' in git.
[ -d $PWD/homedir ] && dir=homedir
[ -d $PWD/skel ] && dir=skel
[ ! -d "$dir" ] \
    && printf "** Error: Directory not found: $dir\n" \
    && printf "** Run this script from directory: $(dirname $0)\n" \
    && exit 2

$git_conf_only || link_all_files
do_install_gitconfig


