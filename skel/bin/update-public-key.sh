#!/bin/bash
##
## Instead of using this script, on linux just use ssh-copy-id
##
## On some systems that utility doesn't exist, so you can either use
## this script, or do the following manually:
##   From your client workstation, 
##      $ ssh-keygen -t rsa
##      $ scp ~/.ssh/id_rsa.pub  {user}@{rmt_Host}:/tmp/{user}-id_rsa.pub
##    Then login to the server (rmt_Host) and run:
##      $ cat /tmp/{user}-id_rsa.pub >> ~/.ssh/authorized_keys
##
## This script does the same thing, but everything is executed
## from the client, to avoid logging into the remost host(s).
##
## Usage: $0 [-e {dsa|rsa}] [-r username] hostname
##    Update public key on remote host 'hostname', using the 
##    given remote host username. The remote username is by 
##    default the same as the local username.  The 'rsa' option
##    is used by default.
##
## Example:  $0 -r remote_user remote_host
##   Generates the local users's public key, gets the remote_user's
##   "authorized_keys" file, concats the local user's public key to the 
##   existing remote_user's authorized_keys list, and then updates the 
##   remote_host's authorized_keys with the updated list.
##   Now, the local user can login as remote_user@remote_host without a
##   password (or using the key passphrase used when generating the key).
##
## Caveats: 
##   * You do have to type in your password a few times the first time, 
##     but you won't have to any more after that.
##   * Anyone who has access to your machine can now login to the remote
##     host without a password.
##

#enc=dsa
enc=rsa

#==========================================================
# usage
#==========================================================
usage() {
 egrep '^##[^#]|^##$' $0 | cut -c3- | sed "s/\$0/$(basename $0)/" 1>&2
}

#==========================================================
# Create tmp files, only readable by user.  Cleanup tmp 
# files on exit. On any error, trap and exit, then cleanup.
#==========================================================
tmp1=/tmp/$$.tmp.rmtkey
tmp2=/tmp/$$.tmp.allkeys

trap 'echo "# cleaning up tmpfiles: $tmp1 $tmp2" && rm -f "$tmp1" "$tmp2" >/dev/null 2>&1' 0
trap "exit 2" 1 2 3 15

create_tmp() {
  [ $# -lt 1 ] && printf "** Expecting temp filename.\n" && exit 2

  for tmpf; do
    if ! touch $tmpf || ! chmod 600 $tmpf ; then
      printf "** Can't create temp file, ${tmpf}\n" && exit 2
    fi
  done
}

#==========================================================
# process args
#==========================================================
[ $# -gt 2 ] && [ "$1" = "-e" ] && shift && enc="$1" && shift
[ $# -lt 1 ] && usage && exit 2

while getopts r:e:h opt
do
  case "$opt" in
  r)
    RUSER="${OPTARG}"
    echo "# using remote username: $RUSER"
    ;;
  e)
    enc="${OPTARG}"
    [ "$enc" = "rsa" -o "$enc" = "dsa" ] || usage && exit 2
    echo "# using encryption: $enc"
    ;;
  h)
    usage && exit 2
    ;;
  *)
    echo "# unknown option, $opt" 1>&2 && usage && exit 2
    ;;
  esac
done

shift $((OPTIND-1)); OPTIND=1

#==========================================================
# main
#==========================================================
ruser=${RUSER:-$USER}
[ -z "$ruser" ] && printf "** Variable \$USER is unset. Exiting...\n" && exit 2

pubkey=~/.ssh/id_${enc}.pub
targkeys="~/.ssh/authorized_keys"
rmthost=${ruser}@${1}

# if false, try running rmt ssh-keygen to create rmt directory ~/.ssh 
# but, it will possibly create the dir with the wrong permissions
mk_rmt_dir=false

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
  printf "\n# Remote keys do not yet exist, creating remote .ssh directory\n"
  if [ "$mk_rmt_dir" = "true" ]; then
    ssh ${rmthost} "mkdir -p $(dirname $targkeys)"
  else
    printf "#  by running ssh-keygen on remote host (typically, just accept defaults): \n"
    ssh ${rmthost} "ssh-keygen"
  fi
fi

cat $pubkey $tmp1 > $tmp2

printf "\n# Copying updated authorized_keys: [scp $tmp2 ${rmthost}:${targkeys}]\n"
scp $tmp2 ${rmthost}:${targkeys} \
  && printf "\n# Finished updating remote public authorized_keys\n" \
  || printf "** Couldn't update remote authorized_keys.\n"


