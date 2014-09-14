#!/bin/bash
## Create a tar file from a directory, optionally using scp to copy
## to a remote directory. Ignores VCS files (git, svn, ade).

# put file in remote remote user's home directory, in ${rmtdir}
rmtuser=${rmtuser:-$USER}
rmtdir=${rmtdir:-"~/temp"}
rmthost=${rmthost:-sfo31000}
localdir="${localdir:-"."}/"
TAR=${TAR:-$(type gtar >/dev/null 2>&1 && echo gtar || echo tar)}


#############################################################################
# print usage
usage_exit() {
   printf "
   Usage: $(basename $0) [-n] [ -r | -t ] [-f tar_filename] [directory...]
   Options:
     -n             do not execute, just print what would be executed
     -r             create tar on remote host (no local file is created)
     -t             create local tar, and use scp to copy to remote host
     -l             only create local tar (do not scp to remote host)
     -F filename    tar filename to use, ignoring ADE view and timestamp.
     -f filename    base of the tar filename to use; by default, tar filename
                    is generated from first arg.

    If in ADE, the filename is generated from the current ADE view,
    for example: $(get_tar_name filename) ($(type -f ade 2>&1 |sed 's/^.*ade: */ade /g'))

    The following defaults may be overridden by setting env vars:
     $ export rmtuser=${rmtuser}        (by default, set to \$USER)
     $ export rmtdir=${rmtdir}
     $ export rmthost=${rmthost}
     $ export TAR=${TAR}
    \n"

  [ $# -gt 0 ] && exit $1
}

#############################################################################
# create tar filename, optionally w/ ADE view in filename
get_tar_name() {
  local first="${1:-backup}"
  local dt=$(date '+%Y-%m-%d_%H-%M-%S' | sed 's/  *//g') # 2012-06-06_05-05-05
  local view=${ADE_VIEW_NAME:-"view_name"}
  local label file

  [ "$view" != "view_name" ] \
      && label=$(ade lsviews 2>/dev/null | egrep "^${ADE_VIEW_NAME} " | cut -d\| -f2 | tr -d ' ')

  [ "$view" != "view_name" ] \
    && file="${first}__${view}__${label:-label}__${dt}.tgz" \
    || file="${first}__${dt}.tgz"

  echo "$file"
}

#############################################################################
# main
[ $# -eq 0 ] && echo "** expecting arguments..." && usage_exit 2

do_rmt_copy="false"
do_local_tar="true"
do_run=
filename=""
default_tname=""
t_name=""
t_opts=" -czh --exclude=.ade_path --exclude=.svn --exclude=.git --exclude=*~ --exclude=.bak --exclude=*.bak "
#t_opts=" $t_opts --exclude=MavenRepo/* "   # no longer necessary
#t_opts=" $t_opts --exclude-vcs "           # not portable

# get options
OPTIND=1
while getopts f:F:hlnrt opt ; do
  case "$opt" in
     f) filename="${OPTARG}"
        echo "** using output filename: $filename"
        ;;
     F) t_name="${OPTARG}"
        echo "$t_name" | egrep -q 'tgz$|tar.gz' || t_name=${t_name}.tgz
        [ "${t_name:0:1}" = "/" ] && localdir=
        ;;
     h) usage_exit 2
        ;;
     l) do_rmt_copy="false"
        do_local_tar="true"
        rmthost=localhost
        ;;
     n) do_run=echo
        echo "** Warning: execution disabled. Just printing what would be executed."
        ;;
     r) do_rmt_copy="true"
        do_local_tar="false"
        ;;
     t) do_rmt_copy="true"
        do_local_tar="true"
        ;;
     *) echo "** Unknown option." 1>&2
        usage_exit 2
        ;;
  esac
done; shift $((OPTIND-1)); OPTIND=1

[ "$default_tname" = "" ] && default_tname="$(echo $(basename "$1") | sed 's/\/*$//g; s/\//_/g; s/^[_-]*//; s/\.[a-z][a-z][a-z0-9]$//')"
[ "$t_name" = "" ] && t_name="$(get_tar_name $default_tname)"

if [ "$filename" != "" ] ; then
  t_name=$(get_tar_name $(basename ${filename}))
  [ $(dirname ${filename:-"."}) != "." ] && localdir=$(dirname "$filename")
fi

# just create remote tarball, no local tar. (if do_run=echo, just print what would be executed)
[ "$do_rmt_copy" = "true" -a "$do_local_tar" = "false" ] \
    && printf "$TAR $t_opts -f - $* | ssh ${rmtuser}@${rmthost} \"cat > ${rmtdir}/${t_name}\"\n" \
    && [ "$do_run" = "" ] \
    && $TAR $t_opts -f - $@ | ssh ${rmtuser}@${rmthost}  "cat > ${rmtdir}/${t_name}" \
    && exit 0 \

# make sure there's not already a tarball here with the same name
[ -f "${localdir}${t_name}" ] \
  && printf "\n** removing old tar file: ${localdir}${t_name}\n" \
  && mv -i "${localdir}${t_name}" "${localdir}${t_name}.$$" \
  && rm -f "${localdir}${t_name}.$$"

[ -f "${localdir}${t_name}" ] \
  && printf "\n** old tar file not removed...exiting" \
  && exit 2

# create local tarball, optionally scp to remote host (if do_run=echo, just print what would be executed)
[ "$do_local_tar" = "true" ] \
    && printf "** run:  $TAR $t_opts -f  ${localdir}${t_name}  $*\n" \
    && $do_run $TAR $t_opts -f "${localdir}${t_name}" $@ \
    && [ "$do_rmt_copy" = "true" ] \
    && printf "** copy to remote: scp  ${localdir}${t_name}  ${rmtuser}@${rmthost}:${rmtdir}/ \n" \
    && $do_run scp "${localdir}${t_name}" ${rmtuser}@${rmthost}:${rmtdir}/ \
    && exit 0

exit 0

