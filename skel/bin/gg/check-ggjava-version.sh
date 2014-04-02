#!/bin/bash

tmpdir=/tmp/z
distdir=$ADE_VIEW_ROOT/oggadp/dist
check_libs=false
check_ggjava=false
check_exe=false
check_exe_name=extract

################################################################################
usage() { cat<<EOF
   Usage: $0 [-j|-l]
    Print versions in ggjava adapter build. Options assume zip is already copied
    and unzipped to tmpdr=$tmpdir
      -a  print ggjava and lib versions
      -e  print extract versions
      -j  print ggjava version
      -l  print lib versions
EOF
  return 0
}

################################################################################
unzip_all() {
  cd $tmpdir && ext2dir.sh *.zip
}

################################################################################
print_exe_version() {
  local e=$1
  [ ! -f $e ] && [ -f ${e}.exe ] && e=${e}.exe
  [ -f $e  ] \
    && printf "   ==== $e \n" \
    && strings $e | egrep '[0-9][0-9]\.[0-9]\.|OGGADP|OGGCORE' | egrep -v '\$Id|/usr/|0[IH]$|^ *IBM'  | sort -u | sed 's/^/    /'
}

################################################################################
print_libs() {
  for y in libggjava_ue.so libggjava_vam.so flatfilewriter.so ggjava_vam.dll ggjava_ue.dll flatfilewriter.dll
  do
    print_exe_version $y
  done
 }

################################################################################
check_distro() {
  cd $tmpdir  \
    && for x in *.zip ; do
      printf "\n================= $x ===================\n"
      d=${x%.*}
      $check_ggjava && (cd $d/ggjava && java -jar ggjava.jar 2>&1 | egrep -v 'SLF4J'; )
      $check_libs && (cd $d && print_libs ; )
      $check_exe && (cd $d && print_exe_version $check_exe_name ; )
    done
  [ -d $tmpdir ]
}


################################################################################
do_unzip() {
  [ -d $tmpdir ] && echo "** error: dir exists: $tmpdir" && usage && exit 2
  [ ! -d $distdir ] && echo "** error: dist dir not found: $distdir" && usage && exit 2
  mkdir -p $tmpdir \
    && cd $distdir \
    && cp *.zip  $tmpdir \
    && unzip_all

}

################################################################################
# main
################################################################################

if [ $# -eq 0 ] ; then
  check_ggjava=true
  check_libs=true
  do_unzip && check_distro
  return
fi

OPTIND=1
while getopts ae:jl opt; do
  case "$opt" in
    a) check_ggjava=true
       check_libs=true
       check_distro
       ;;
    e) check_exe=true
       check_exe_name=$OPTARG
       check_distro
       ;;
    j) check_ggjava=true
       check_distro
       ;;
    l) check_libs=true
       check_distro
       ;;
    h | *) usage;;
  esac
done; shift $((OPTIND-1)); OPTIND=1


