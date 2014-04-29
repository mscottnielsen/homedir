#!/bin/bash
#
# Download supporting BugDB files from the internal bug-sftp site.
#
# [Update 2012-December - updated for new bug sftp site. Old anon ftp access has been disabled.]
# Note: this only works for the bug sftp site; it doesn't work for SR uploads to MOS.

# typical url's
# https://bugsftp.us.oracle.com/bug/faces/BugUploadMain.jspx?bug=14510723
# https://bugsftp.us.oracle.com/bug/filedownloadservlet?bug=15896781&FileName=GSI_JAD2.rpt_20Nov_0711

###########################################################################
# get this program's name & dir (allowing for symlinks)
prog=${PROG_PATH##*/}
user="mike.nielsen@oracle.com"

###########################################################################
# pass err msg or return status
usage() { cat<<EOF_USAGE
  Usage: $prog [bug_no|url] [description]
    Creates a directory bug_{number} containing the bug ftp files.
    Or, if given a description, bug_{number}_{desc}
EOF_USAGE
}

usage_exit() {
  [ $# -gt 0 ] && printf "\n** Error: $*\n\n"
  usage
  exit 2
}

###########################################################################
# unsets env vars for http/ftp proxy (http_proxy ftp_proxy HTTP_PROXY FTP_PROXY ...)
unset_proxy() {
  for x in $( env | egrep -i '^[fh]t*tp.*_proxy' | cut -d= -f1 ); do
    echo "** unsetting: ${x}="\"$(eval echo \$$(echo $x))\"
    unset $x
  done
}

###########################################################################
die() {
  printf "** Error: $*\n"
  exit 2
}

###########################################################################
setup() {
  local bugdir=$1

  [ -d "$bugdir" -a "$use_existing_dir" = "false" ] && die "directory already exists: $bugdir"
  type lftp >/dev/null 2>&1  || die "lftp not found (required to download bug artifacts)"
  mkdir -p "$bugdir" || die "can't create dir: $bugdir"
  cd "$bugdir"       || die "can't chdir to $bugdir"

  return 0
}

############################################################################
# convert to upper/lowercase, copy to x buffer
convert_case() {
  #set -x
  local opt OPTIND OPTARG
  local mytr=${TR:-"tr"} upper='[A-Z]' lower='[a-z]'
  local from=$upper to=$lower

  usage() { cat<<EOF_USAGE
    Convert to upper/lowercase, copy to clipboard, reformat text.
    Usage:  [-l|-u|-s|-c|-h] {desc}
      -c  save output to clipboard (-C to leave newlines)
      -h  print usage
      -l  convert to lowercase/uppercase
      -u  convert to lowercase/uppercase
      -s  replace spaces with '_'
EOF_USAGE
  }

  do_subst() { cat; }

  do_output() { cat; }

  while getopts cClusx opt ; do
    case $opt in
      c) do_output() { tr -d '\n' | tr -d '\r' | xclip -i -selection clipboard ; } ;;
      C) do_output() { xclip -i -selection clipboard ; } ;;
      l) from=$upper; to=$lower ;;
      u) from=$lower; to=$upper ;;
      s) do_subst() { sed 's/ /_/g'; } ;;
      h | *) usage; return 2;;
    esac
  done; shift $((OPTIND-1)); OPTIND=1

  if [ $# -eq 0 ]; then
    $mytr "$from" "$to" | do_subst | do_output
  else
    echo "$@" | $mytr "$from" "$to" | do_subst | do_output
  fi
  #set +x
}

to_lower() {
  convert_case -l $@
}

to_upper() {
  convert_case -u $@
}

###########################################################################
get_files() {
  local bugno=$1  #  e.g., bugno=14510723
  local bugdir=$2
  local pw=${pw:-$PASSWD}

  pwd

  [ "$pw" = "" ] && read -s -p "Enter SSO password: "  pw
  echo ${pw//?/#}
  [ "$pw" = "" ]   && die "sftp (SSO) password not given"

  unset_proxy

  # lftp -u username,password
  #    -e "mirror –delete –only-newer –verbose path/to/source_directory path/to/target_directory;quit" ftpsite
  # or: mirror --use-pget-n=5

  echo "lftp -u \"$user,${pw//?/#}\" sftp://bugsftp.us.oracle.com"
  lftp -u "$user,$pw" sftp://bugsftp.us.oracle.com  <<EOF
  cd /$bugno
  mget *
EOF
  cd -
}

###########################################################################
# main: make directory, download bug artifacts into it

input=
desc=
bugno=
filen=
yn=n
outdir=
use_existing_dir=false

[ $# -gt 0 -a "$1" = "-d" ] && use_existing_dir=true && shift

# Argument could be URL or bug number
[ $# -lt 1 ] && usage_exit "Expecting argument: bug number (e.g., 123456789) or bug URL"
input=$1
shift

if [ "$input" -eq "$input" ] 2>/dev/null
then
  bugno=$input  # given bug number as argument
else
  bugno=$(echo "$input" | sed 's/^.*bug=\([0-9]*\).*/\1/')
  rptno=$(echo "$input" | sed 's/^.*rptno=\([0-9]*\).*/\1/')
  filen=$(echo "$input" | sed 's/^.*FileName=\([^&]*\).*/\1/')
  [ "$filen" = "$input" ] && filen=
  [ "$bugno" -eq "$bugno" ] 2>/dev/null || bugno=
  [ "$bugno" = "" -a "$rptno" != "" -a "$rptno" -eq "$rptno" ] 2>/dev/null && bugno=$rptno
  [ "$filen" = "" ] && filen="*"
fi

[ "$bugno" = "" ] && usage_exit "Expecting a bug number"
outdir="bug-${bugno}"

[ $# -gt 0 ] && desc=$(echo "$*" | to_lower | sed s'/ /_/g; s/[-_][-_]*/_/g; s/^[-_]//' )
[ "$desc" != "" ] && outdir="${outdir}-${desc}"

setup $outdir

printf "
 Downloading:
   bug=$bugno
   file(s)=\"$filen\"
   desc=\"$desc\"
   dir=$outdir\n\n"

read -n1 -p '==================== Ready? [y|n] (n)' yn && echo
[ "$yn" != "y" ] && echo '...ok, exiting...' && exit 1

get_files $bugno $outdir


