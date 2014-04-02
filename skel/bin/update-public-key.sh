#!/bin/bash
##
## Legacy script used before ssh-copy-id was commonly available.
##

PROG_PATH=${BASH_SOURCE[0]}      # this script's name
PROG_NAME=${PROG_PATH##*/}       # basename of script (strip path)
#PROG_DIR="$(cd "$(dirname "${PROG_PATH:-$PWD}")" 2>/dev/null 1>&2 && pwd)"

usage() { cat<<EOF_USAGE
  NOTE: Instead of using this script, just use ssh-copy-id (if available).

  Usage: $PROG_NAME [-e {dsa|rsa}] [-r {user}] {host}
    Update public key on remote {host} as {user}, by default 'rsa'.

  Example:  $PROG_NAME -r remote_user remote_host
    Generate the local user's public key, appending to the remote_user's
    "authorized_keys" file.  Allows the local user to login to remote_host
    without a password (or using the key passphrase, if required)
EOF_USAGE

  [ $# -gt 0 -a "$1" = "-v" ] || return 0

cat<<EOF_USAGE2
  Caveats:
    * use ssh-copy-id if it exists (this script is a work-around
      for when it doesn't exist, which is less common these days)
    * your password will have to be entered a few times to run the script,
      but you won't have to any more after that (assuming you did not type
      a passphrase for your key)
    * typically you do *not* want to use a passphrase, if doing distributed
      processing (eg., hadoop, et al.); but *do* want one for logging in
      to servers, accessing git repo, etc (for remembering your passphrase,
      see: ssh-agent)

  If ssh-copy-id doesn't exist, you may do the following manually (this
  script does the same, but all executed from the client):
    From your client host,
       $ ssh-keygen -t rsa
       $ scp ~/.ssh/id_rsa.pub  {user}@{rmt_host}:/tmp/{user}-id_rsa.pub
    Then login to rmt_host (optionally, to setup proper permissions, see below):
       $ cat /tmp/{user}-id_rsa.pub >> ~/.ssh/authorized_keys
       $ rm -f /tmp/{user}-id_rsa.pub

    Optionally, to setup proper permissions on the remote host,
    * to create ~/.ssh with proper permissions, either run ssh-keygen, or:
        $ mkdir ~/.ssh && chmod 700 ~/.ssh
    * to create authorized_keys,
        $ test -f  ~/.ssh/authorized_keys || { touch ~/.ssh/authorized_keys; chmod 600 ~/.ssh/authorized_keys; }
EOF_USAGE2
}


###########################################################################
# Create tmp files, only readable by user, cleanup on exit
tmp1=/tmp/tmp.${USER}.$$.rmtkey.tmp
tmp2=/tmp/tmp.${USER}.$$.allkeys.tmp

trap 'echo "# cleaning up tmpfiles: $tmp1 $tmp2" && rm -f "$tmp1" "$tmp2" >/dev/null 2>&1' 0
trap "exit 2" 1 2 3 15

create_tmp() {
  [ $# -lt 1 ] && printf "** Expecting temp filename.\n" && exit 2
  for tmpf; do
    if ! touch $tmpf || ! chmod 600 $tmpf; then
      printf "** Can't create temp file, ${tmpf}\n" && exit 2
    fi
  done
}

###########################################################################
# main
#
do_ssh_copy_id() {
  local opt OPTIND OPTARG
  local enc pubkey targdir targkeys rmthost
  local mkdir_rmt=false   # false: use ssh-keygen instead of mkdir to create ~/.ssh

  while getopts r:e:h opt; do
    case "$opt" in
    r) ruser="${OPTARG}"
       echo "# using remote username: $ruser"
       ;;
    e) enc="${OPTARG}"
       [ "$enc" = "rsa" -o "$enc" = "dsa" ] || { usage; exit 2; }
       echo "# using encryption: $enc"
       ;;
    h) usage; exit 2
       ;;
    *) echo "# unknown option, $opt" 1>&2; usage; exit 2
       ;;
    esac
  done; shift $((OPTIND-1)); OPTIND=1

  [ "$enc" = "" ] && enc=rsa
  [ "$ruser" = "" ] && ruser=$USER
  [ -z "$ruser" ] && { printf "** Error: User must be set.\n"; usage; exit 2; }

  pubkey=~/.ssh/id_${enc}.pub
  targdir="~/.ssh"
  targkeys="$targdir/authorized_keys"
  rmthost=${ruser}@${1}

  create_tmp $tmp1 $tmp2 || exit 2

  [ ! -f $pubkey ] \
    && printf "\n# Create public/private key pair; public key=${pubkey}\n" \
    && ssh-keygen -t ${enc}

  printf "\n# Copy remote: [${rmthost}:${targkeys}] to local: [${tmp1}]\n"
  if scp ${rmthost}:${targkeys} $tmp1
  then
    printf "\n# Concatenate public keys to file ${tmp2}: ${pubkey} ${tmp1}\n"
  else
    cat /dev/null > $tmp1
    printf "\n# Remote authorized_keys do not exist, creating remote .ssh directory\n"
    if $mkdir_rmt; then
      ssh ${rmthost} "mkdir -p $targdir; chmod 700 $targdir"
    else
      printf "#  by running ssh-keygen on remote host (typically, just accept defaults): \n"
      ssh ${rmthost} "ssh-keygen"
    fi
  fi

  cat $pubkey $tmp1 > $tmp2

  printf "\n# Copying updated authorized_keys: [scp $tmp2 ${rmthost}:${targkeys}]\n"
  scp $tmp2 ${rmthost}:${targkeys} \
    && printf "\n# Finished updating remote authorized_keys\n" \
    || printf "** Error: Couldn't update remote authorized_keys.\n"
}

do_ssh_copy_id "$@"


