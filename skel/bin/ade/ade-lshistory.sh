#!/bin/bash

######################################################################
# print usage; if given an exit status do exit, otherwise just return.
print_usage() { cat<<EOF
 Usage: ${BASH_SOURCE[0]##*/} {file}
   Print history of a file in ADE in 'unified diff' format, one version
   to the next, from some version (default, version 0) through some end
   version (default, latest versino).  Simple wrapper around 'ade lshistory',
   showing the history (ade diff) of an inidivdual file over time.

  Options:
    -b {ver}  start printing diff's from this version
    -e {ver}  stop printing diff's at this version
    -p        page results through \$PAGER (by default, 'less')
    -r {a..b} start/stop range for printing diffs; for example,
              given: -r 12..15 => print diff 12-13, then 13-14, 14-15
    -C        print comments (and no diff's)
    -D        print diff's (and no comments)
    -h        print this help/usage message
EOF
  [ $# -gt 0 ] && exit $1
  return 0
}

######################################################################
fawk_comments() {
  local A=$1
  local B=$2
  local C="^ *$"
  local D="^ *$"

  awk -vA="$A" -vB="$B" -vC="$C" -vD="$D" '
     BEGIN {
           toggle=0;
           cnt=0;
           #print "=======from: [" A "]";
           #print "=========to: [" B "]";
     }

     $0 ~ "^"A"$"  {
           if(cnt==0) { toggle=1; }
           cnt++;
     } toggle;

     $0 ~ "^"B"$" {
           if(cnt>1) { toggle=0; }
           cnt++;
     } 0;

     $0 ~ "^ *$" {
           if(cnt>1 && toggle==1) { cnt++; }
     } 0;

     $0 ~ "^ *$" {
           if(cnt>2) { exit; };
     } 0;'
}


######################################################################
# print comments between two versions
#
print_comments() {
    local file=$1 v1=$2 v2=$3
    local from="${v1//\//.}" to="${v2//\//.}"

    $verbose && printf "#== file=$file\n"
    $verbose && printf "#==== v1[$i]=$v1\n"
    $verbose && printf "#==== v2[$j]=$v2\n\n"

    ade lshistory "$file" 2>&1 | fawk_comments "$from" "$to"
    return 0
}




######################################################################
# print diff between two ade file versions
#
print_diff() {
    local v1=$1 v2=$2
    printf "#$DELIM_LONG_LINE"
    ( cd $ADE_VIEW_ROOT
      printf "#== ade diff -diff_args \"-r -u -N\" $v1 $v2\n"
      ade diff -diff_args "-r -u -N" $v1 $v2 )
    return 0
}

######################################################################
# list file history
#
ade_lshistory() {
  local i j v1 v2 ade_fullpath ade_basename versions file=$1

  # convert short filename (foo) to relative path (./foo), so that ade-ls is consistent
  echo "$file" | grep -q '/' || file="./$file"
  ade_fullpath=$(ade ls $file | egrep -v 'WARNING|ERROR')
  ade_basename=${ade_fullpath%/*}

  if $verbose ; then
      printf "\n"
      printf " (debug) \$file=$file\n (debug)"
      printf " (debug) ade_fullpath=$ade_fullpath\n"
      printf " (debug) ade_basename=$ade_basename\n"
      printf " (debug) range=$ver_bgn .. $ver_end\n\n"
      printf "\n"
  fi

  [ ${#ade_basename} -le 2 ] \
     && echo "** error: unable to get basename for ADE file: \"$file\" (ade file=\"$ade_fullpath\", basename=\"$ade_basename\")" 1>&2 \
     && return 2

  versions=( $(ade lshistory $file | egrep -v ':|^Getting.*metadata' | egrep "${ade_basename}/[0-9]{1,}") )

  (( ver_tot = ${#versions[@]} -1 ))
  [ ${ver_end:-0} -gt $ver_tot ] && ver_end=$ver_tot

  $verbose && printf "\n#=== $file (${ver_bgn}..${ver_end}) ($ver_tot versions)===\n"

  for ((i=${ver_bgn:=0}; i < ${ver_end:=$ver_tot}; i++)) ; do  #for ((i=0; i < ver_tot; i++))
    (( j = i+1 ))
    (( k = j+1 ))
    v1=${versions[i]}
    v2=${versions[j]}

    printf "#$DELIM_LONG_LINE"
    printf "#== $file: compare v$i and v$j (range=${ver_bgn}..${ver_end}, total revisions=$ver_tot)\n"
    $do_cmnts && print_comments  "$file" "$v1" "$v2"
    $do_diffs && print_diff "$v1" "$v2"

  done | $pager
  return 0
}

######################################################################
# main
#
DELIM_LONG_LINE="================================================================================\n"
verbose=false
pager=cat      # optionally page the output through 'less' (or more)

do_diffs=true  # print out unified diff's
do_cmnts=true  # include the comments for each diff

ver_bgn=
ver_end=

OPTIND=1
while getopts b:CDe:hpP:r:v opt; do
  case "$opt" in
    b) ver_bgn=$OPTARG
       ;;
    C) do_cmnts=true
       do_diffs=false
       ;;
    D) do_diffs=true
       do_cmnts=false
       ;;
    e) ver_end=$OPTARG
       ;;
    p) pager=${PAGER:-"less -X"}
       ;;
    P) pager=${OPTARG}
       ;;
    r) echo "${OPTARG}" | grep -q '\.\.' \
          && printf "# version range given ($OPTARG): " \
          || { echo "** error: expecting range (begin..end)"; print_usage 2; }
       ver_bgn=${OPTARG%..*}
       ver_end=${OPTARG#*..}
       ;;
    h) print_usage 0
       ;;
    v) verbose=true
       ;;
    *) print_usage 2
       ;;
  esac
done; shift $((OPTIND-1)); OPTIND=1

[ $# -eq 0 ] && { printf "** Error: expecting filename.\n"; print_usage 2; }

printf "version range: ${ver_bgn:-"0"} => ${ver_end:-".."}\n"

for file
do
  ade_lshistory "$file" \
    || { echo "** error: can't get history for file \"$file\" (exiting)" 1>&2; exit 2; }
done

