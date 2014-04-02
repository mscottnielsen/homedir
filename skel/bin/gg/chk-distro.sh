#!/bin/bash
#
# creaete an index of a GG zip distro
#


################################################################
# extract tar file (if not windows)
do_untar() {
  if $is_windows ;  then
    printf "** warning: detected windows\n"
  else
    tarfile=$(ls *.tar 2>/dev/null)
    [ -f "$tarfile" ] \
       && tar xf $tarfile \
       && return 0 \
       || { printf "** warning: unable to extract tar:  $tarfile\n"; return 1; }
  fi
  return 0
}

################################################################
# file files/links/directories and list to given file
do_list() {
  local what=$1
  local out=$2
  local ftype=${1:0:1}

  echo "==== $what =======" >> $out
  #find * -type $ftype  -print0  | xargs --null ls -ld | sort >> $out
  find . -type $ftype  -print0  | xargs --null ls -ld | sort >> $out
}


################################################################
# generate file list, md5sum of tmp directory
do_index() {
  echo "== $name" > $idx
  echo "Generate index: $zp == $(date)" >> $idx
  echo "====md5=========" >> $idx
  #find * -type f -print0  | xargs --null md5sum  | sort -k2 >> $idx
  find . -type f -print0  | xargs --null md5sum  | sort -k2 >> $idx

  do_list files $idx
  do_list links $idx
  do_list dirs  $idx
}

################################################################
# create tmp dir of zip, generate index
do_index_zip() {
  [ -f "$idx" ] && printf "** error: index exists: $idx\n" && return 2
  ( mkdir $tmpd \
    && touch $idx \
    && cd $tmpd \
    && unzip -q ../${name}.zip \
    && do_untar \
    && do_index \
    && return 0 \
    || return 2 )
}  



################################################################
process_zips() {
  for zp
  do
    printf "=== processing: $zp ==========\n"
    name=$(basename $zp .zip)
    tmpd=${name}.tmp
    idx=$PWD/${name}.index
    
    [ ! -f "$zp" ] && printf "** error: expecting zip, file not found: $zp\n" && return 2
    [ -d "$tmpd" ] && printf "** error: directory exists: $tmpd\n" && return 2
    echo $name | grep Windows && is_windows=true || is_windows=false
    
    do_index_zip|| return 2
    
    [ ${#tmpd} -ge 4 -a -d "$tmpd" ] && rm -fr "$tmpd"
  done
}




################################################################
# main
################################################################

if [ $# -gt 1 -a "$1" = "-d" ] ;
then
  shift
  for tmpd
  do
    name=$(basename $tmpd .tmp)
    name=$(basename $name .zip)
    idx=$PWD/${name}.index
    ( cd $tmpd && do_index ; cd - ;  ) 
  done
else
  process_zips "$@"
fi


