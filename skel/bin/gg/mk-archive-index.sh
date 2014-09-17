#!/bin/bash
#
usage () { cat<<EOF
  Usage: $(basename $0) [-d dir]
  Create an 'index' file for a zip distribution, including
  all files and directories. For files, a "md5" list will be
  generated for all files. In order to list a tar file in a zip,
  the tar is extracted to a temp dir, then listed.
  Options:
     -d {dir}   process all zips in the given directory
EOF
  return 0
}



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
# 'find' all {files,links,dirs}, and run the given program (eg,
# cmd="ls -ld" or "md5sum"); sort results on the last column.
do_find_sorted_run() {
  local ftype=${1/-/}; ftype=${ftype:0:1}  # use { "-f", "f", "foo"} => "f"
  shift
  local cmd=$@
  find . -type $ftype -print0 \
       | xargs --null $cmd \
       | awk '{print $NF"|"$0}' \
       | sort -t'|' -k1 \
       | awk -F'|' '{print $NF}'
  }

################################################################
# generate file list, md5sum of tmp directory
do_index() {
  # name, zp, idx
  echo "== $name" > $idx
  echo "Generate index: $zp == $(date)" >> $idx

  echo "====md5=========" >> $idx
  do_find_sorted_run -f "md5sum" >> $idx

  echo "==== files =======" >> $idx
  do_find_sorted_run -f "ls -ld" >> $idx

  echo "==== links =======" >> $idx
  do_find_sorted_run -l "ls -ld" >> $idx

  echo "==== dirs ========" >> $idx
  do_find_sorted_run -d "ls -ld" >> $idx
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
[ $# -gt 0 -a "$1" = "-h" ] && usage && shift && exit 0

if [ $# -gt 1 -a "$1" = "-d" ]       # process directory of zip files
then
  shift
  for tmpd
  do
    name=$(basename $tmpd .tmp)
    name=$(basename $name .zip)
    idx=$PWD/${name}.index
    ( cd $tmpd && do_index ; cd - ; )
  done
else                                 # process one or more zip files
  process_zips "$@"
fi


