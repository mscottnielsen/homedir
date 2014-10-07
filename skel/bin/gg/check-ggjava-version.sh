#!/bin/bash

TEMPDIR=/tmp/tmpdist/$LOGNAME
DIRNUM=$$
DISTDIR=.

CHECK_GGJAVA=true
CHECK_LIBS=true

CHECK_EXE=false
EXE_NAME=extract

NATIVE_LIBS="libggjava_ue.so \
         libggjava_vam.so \
         flatfilewriter.so \
         ggjava_vam.dll \
         ggjava_ue.dll \
         flatfilewriter.dll"

#echo $NATIVE_LIBS
#exit 0

# cleanup tmp files on exit. On any error, trap and exit, then cleanup
#trap 'echo "clean up tempdir=$TEMPDIR... $(test -d "$TEMPDIR" && ls $TEMPDIR && rm -f "${TEMPDIR}")" 1>&2' 0
#trap 'echo "# cleaning up tempdir=$TEMPDIR" && echo rm -f "$TEMPDIR" >/dev/null 2>&1' 0
trap 'echo "######### cleaning up tempdir=$TEMPDIR" && ls -l $TEMPDIR && rm -f "$TEMPDIR"' 0

trap "exit 2" 1 2 3 15


################################################################################
usage() { cat<<EOF
 Usage: $0 [-a -e {exe} -h -j -l] [-t {tmpdir}] {file}
 Print versions of components in the GG Adapter build. Builds are copied
 from some distribution directory and unzipped to a temp directory and
 version strings attempted to be collected from the binaries.
    -A       get zip's from the ADE distribution directory for OGGADP
    -a       print versions of all components
    -e {exe} print version of the given executable; e.g., -e extract
    -j       print version of ggjava java jar
    -l       print versions of libraries
    -t {dir} temp extract dir
 Default binary directory: $DISTDIR
 Default temp directory: $TEMPDIR/$$ (suffixed by {user/pid: $LOGNAME/$$)
EOF
  return 0
}

################################################################################
die() {
  local print_usage=false
  [ "$1" = "-u" ] && shift && print_usage=true
  err "$@"
  $print_usage && usage
  exit 2
}

################################################################################
# can't pass "!" to printf directly
output_comment() {
    printf -- "<\041--$@ -->\n"
    return 0
}
output_start() {
    local tag=$1
    shift
    printf -- "<$tag $@>\n"
    return 0
}
output_end() {
    printf -- "</${1}>\n"
    return 0
}
warn() {
    printf "** warning: $@" 1>&2
    return 0
}
err() {
    printf "** error: $@" 1>&2
    return 0
}

################################################################################
print_version() {
  local xfile
  for xfile; do
    [ ! -f "$xfile" -a -f "${xfile}.exe" ] && xfile="${xfile}.exe"
    if [ -f "$xfile"  ]; then
        output_start version "artifact=\"${xfile}\""
        #output_comment "   ==== ${xfile}"
        if [ "${xfile##*.}" = "jar" ]; then
          java -jar $xfile 2>&1 | egrep -v 'SLF4J'
        else
          strings $xfile | egrep '[0-9][0-9]\.[0-9]\.|OGGADP|OGGCORE' | egrep -v '\$Id|/usr/|0[IH]$|^ *IBM'  | sort -u | sed 's/^/    /'
        fi
        output_end version
    fi
  done
}

################################################################################
check_distro() {
  local dir xfile
  ( cd $TEMPDIR && \
    for xfile in *.zip ; do
      dir=${xfile%.*}
      output_comment "================= $xfile / $dir ==================="
      output_start dist "name=\"$xfile\""

      $CHECK_GGJAVA && output_comment "======== ggjava version:" \
        && (cd $dir/ggjava 2>/dev/null || cd $dir/ggs_Adapters*/ggjava; print_version ggjava.jar; )

      $CHECK_LIBS && output_comment "======== libs version:" \
        && (cd $dir 2>/dev/null || cd $dir/ggs_Adapters*/; print_version $NATIVE_LIBS ; )

      $CHECK_EXE && output_comment "======== exe version:" \
        && (cd $dir 2>/dev/null || cd $dir/ggs_Adapters*/; print_version $EXE_NAME ; )

  done; )
  [ -d $TEMPDIR ]
}


################################################################################
do_unzip() {
  local dir1 dir2 base f files
  [ -d $TEMPDIR ] && die -u "** error: target temp directory exists: $TEMPDIR"
  [ ! -d $DISTDIR ] && die -u "** error: distribution directory does not exist: $DISTDIR"

  [ $# -eq 0 ] && return 1

  mkdir -p $TEMPDIR
  [ ! -d $TEMPDIR ] && { err "can't create temp directory $TEMPDIR" ; return 2; }

  files=$(for f ; do [ -f $f -o -h $f ] && echo "$f" || warn "file does not exist: $f"; done; )
  #files=$*

  cp $files $TEMPDIR
  dir1=$PWD
  cd $TEMPDIR && for zip in * ; do
      base=${zip%.*}
      mkdir $base
      ( cd $base
        unzip -q ../$zip || err "can't unzip file: $zip"
        output_start filelist "file=\"$zip\""
        ls -l
        output_end filelist
        for tarball in *.tar; do
            tar xf $tarball || err "unable to untar file: $tarball"
        done; )
  done
  cd $dir1
}

################################################################################
# main
################################################################################

OPTIND=1
while getopts ae:hjlt: opt; do
  case "$opt" in
    A) DISTDIR=$ADE_VIEW_ROOT/oggadp/dist
      ;;
    a) # enable every check
       CHECK_GGJAVA=true
       CHECK_LIBS=true
       CHECK_EXE=true
      ;;
    e) # just exe check
       CHECK_GGJAVA=false
       CHECK_LIBS=false
       CHECK_EXE=true
       EXE_NAME=${OPTARG}
      ;;
    j) # just ggjava
       CHECK_GGJAVA=true
       CHECK_LIBS=false
       CHECK_EXE=false
      ;;
    l) CHECK_LIBS=true
       CHECK_EXE=false
       CHECK_GGJAVA=false
      ;;
    t) TEMPDIR=${OPTARG}
      ;;
    h|*) usage
      ;;
  esac
done; shift $((OPTIND-1)); OPTIND=1

TEMPDIR=${TEMPDIR}/$DIRNUM

files="$DISTDIR/*.zip"
[ $# -gt 0 ] && files="$@"

cat<<EOF
<!-- ================================================
dist directory: ${DISTDIR}
temp directory: ${TEMPDIR}
args($#): $@
================================================
$(ls -ld $files;)
================================================ -->
EOF

do_unzip $files   # if checking a zip file; unnecessary if checking existing installation
check_distro      # print version info of components (as xml)

