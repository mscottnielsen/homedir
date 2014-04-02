#!/bin/bash
#
# Search for files matching a given pattern in zip/tar files (e.g., OGG dist's)
#


#############################################################################
## filenames that must exist inside zip/tar files (not necessarily all files,
## just the files that have a tendency to go missing without notice....)
oggadp_filelist="flatfilewriter{.so,.dll} gendef{,.exe} ggjava/ggjava.jar libggjava_ue.so libggjava_vam.so ggjava_ue.dll ggjava_vam.dll"
oggcore_filelist="replicat{,.exe} logdump{,.exe} extract{,.exe} defgen{,.exe} defgen{,.exe}"

## string patterns (filenames) to verify exist inside zip/tar files.
#check='file.*exe$|file.*so$|file.*dll$|java.*exe|java.*so$|java.*dll$|gendef|ggjava/ggjava.jar$|pdf$'

prog=${BASH_SOURCE[0]##*/}  # this program name (basename $0)
pid=$$                 # this process pid (for temp files)
keep_tmpzip=0          # keep temp file after run (/tmp/temp-{user}-{pid}*.zip)
quiet=1                # disable verbose
verbose=0              # -v for verbose, "-v -v" for more verbose
print_perms=0           # print unix permissions in output

TEMPDIR=${TEMPDIR:-/tmp} # override default tmp working dir for temp zip files


#############################################################################
# Running with no arguments:
#  $ check-oggadp-libs.sh OGGADP_MAIN_PLATFORMS/OGGADP_MAIN_PLATFORMS_120612.0700__2012-06-12_16-20/ggs_Adapters_Linux_x64.zip
#  $ check-oggadp-libs.sh OGGADP_MAIN_PLATFORMS/OGGADP_MAIN_PLATFORMS_120612.0700__2012-06-12_16-20/ggs_Adapters_Linux_x64.zip
#  ==== OGGADP_MAIN_PLATFORMS/OGGADP_MAIN_PLATFORMS_120612.0700__2012-06-12_16-20/ggs_Adapters_Linux_x64.zip
#    == ggs_Adapters_Linux_x64.tar
#          341028 2012-06-12 10:14 flatfilewriter.so
#          304404 2012-06-12 10:14 gendef
#            8830 2012-03-22 02:21 ggjava/ggjava.jar
#           203942 2012-06-12 10:14 libggjava_ue.so
#           319183 2012-06-12 10:14 libggjava_vam.so
#
#
# To grab a buid from the CI sever (ipubs), use wget:
# $  wget -x -nH --cut-dirs=6  http://ipubs.us.oracle.com/depot/files/builds/snapshots/GoldenGate/OGGADP/OGGADP_MAIN_PLATFORMS/OGGADP_MAIN_PLATFORMS_120612.0700__2012-06-12_16-20/ggs_Adapters_Linux_x64.zip
#    Which saves the file to:
#       OGGADP_MAIN_PLATFORMS
#           |-----OGGADP_MAIN_PLATFORMS_120612.0700__2012-06-12_16-20
#                         |-----/ggs_Adapters_Linux_x64.zip'



#############################################################################
usage() {
  printf "
     Search for files matching a given pattern in zip/tar files (e.g., OGG dist's)
     Usage: ${prog} [-p] [-g] [-h] {zipfile}
        -p     - keep permissions in output
        -g)    - also search for key OGGCORE executables
        -h     - print usage

     Debug-only options:
         -k  - keep temp zip file (in /tmp/temp-${LOGNAME}-{pid}*.zip)
         -v  - verbose (use option twice to be more verbose)

     Env vars:
         Set TEMPDIR to something other than /tmp to change where 
         temporary zip files are made (TEMPDIR=${TEMPDIR}).
\n"
}




##############################################################################
# For all given arguments, create an "or" regexp (even if extra whitespace in input).
# Options:
#    -w  - match whole words, i.e., "^word$" vs. just "word$" . The default is to just
#          match on word end ("word$").  So pattern "bar$" would match "bar" and "foobar".
#    -s  - include a blank space at the beginning of the pattern, e.g,  " word$".
#          Thus pattern "bar$" would only match " bar" , not "foobar".
# Example:
#  $ regexp_from_list -w one two three four foo.bat foo.bar
#    "^one$|^two$|^three$|^four$|^foo.bat$|^foo.bar$"
#
#  $ regexp_from_list    one two three four foo.bat foo.bar
#    "one$|two$|three$|four$|foo.bat$|foo.bar$"
#
#  $ regexp_from_list -s one two three four foo{.bat,.bar}
#    " one$| two$| three$| four$| foo.bat$| foo.bar$"
#
# The following return the same string:
#  *  one two three four foo.bat foo.bar
#  *  "one   two\n three\n\n four\n foo.bat  foo.bar"
#  *  {one,two} three four foo{.bat,.bar}"
#
regexp_from_list() {
  local opt OPTIND OPTARG
  local all="."
  local pat='&\$'
  [ "$1" = "-w" ] && pat='^&\$' && shift
  while getopts ws opt; do
    case "$opt" in
    w) pat='^&\$';;
    s) pat=' &\$';;
    esac
  done; shift $((OPTIND-1)); OPTIND=1

  #  [ $# -gt 0 ] \
  #      && all=$(eval echo "$*" | tr '\12' ' ' | sed "s/  */ /g; s/  *$//; s/^  *//g; s/[^ ][^ ]*/$pat/g; s/ /|/g")

   local input=$(echo "$*" | tr '\12' ' ')

   all=$(for p in $(eval "echo $input"); do
           printf "$p" | sed "s/[^ ][^ ]*/|$pat/g"
         done | sed 's/^|//')

  [ "$all" = "" ] && all="."

  echo "$all"
  return 0
}


#############################################################################
log_debug() {
 #[ $verbose -ge 1 ] && printf -- "[DEBUG] $@\n"
 [ $verbose -ge 0 ] && printf -- "[DEBUG($verbose)] $@\n"
}


check=$(regexp_from_list $oggadp_filelist)


#############################################################################
OPTIND=1
while getopts kqgvxhp opt; do
  case "$opt" in
  k) keep_tmpzip=1 ;;
  q) quiet=1 ; verbose=0 ;;
  p) print_perms=1;;
  g) check=$(regexp_from_list $oggadp_filelist $oggcore_filelist) ;;
  v) (( verbose ++ )) ; quiet=0 ;;
  x) x=true;  arg=${OPTARG} ;;
  h) usage && exit 2 ;;
  *) echo "unknown option" 1>&2 && usage && exit 2 ;;
  esac
done; shift $((OPTIND-1)); OPTIND=1


## indent by the given level (default=2). E.g., filter_indent 4
filter_indent() {
  local depth=${1:-2}
  local str=$(for i in $(seq 1 ${depth}); do printf "  "; done)
  sed "s/.*/ $str  & /"
  return 0
}

## remove "-rw-rw-rw" persmissions from output stream
filter_perms() {
  [ $print_perms -eq 0 ] \
    && sed 's/^-[^\/]*[^ ]*//' \
    || cat
  return 0
}

## Filter and reformat. Grep's for filename pattern(s), and reformats
##  output to strip unix permissions and add indentation
filter_grep() {
  [ $verbose -le 1 ] \
    && egrep "$check" | filter_perms | filter_indent \
    || filter_perms | filter_indent
  return 0
}

test_zip() {
  log_debug "testing zip: $1\n"
  [ $# -lt 1 -o ! -f "$1" ] && echo "** Error: zip archive not found: $1" 1>&2 && return 3
  unzip -q -t "$1" || { echo "** Error: bad zip archive: $1" 1>&2;  return 3; }
  return 0
}

#############################################################################
## Search through zip for tar files, then search through tar using regexp.
##   usage: search_inside_zip [-z] {tar...}
##     -z  nested tar needs to be explicitly gunzip'ed (not usually
##         necessary; gnu tar can figure this out on its own) (not implemented)
search_inside_zip() {
  local z=$1 tarball=""

  log_debug "(begin) search_inside_zip: $z\n"
  test_zip "$z" || return 3

  # look at the top level of the archive for files
  unzip -l $z | filter_grep

  for tarball in $(unzip -l "$z" | egrep '\.tar$' | awk '{ print $NF }')
  do
    printf "  == $tarball\n"
    unzip -p "$z" "$tarball" | tar -tvf - | filter_grep
  done
  log_debug "(done) search_inside_zip: $z\n"
}

#############################################################################
# list contents of nested zip file(s), search for files matching patterns.
# if there is a nested zip or tar, also search through those.
#   usage: zipfile {regexp_pattern}
search_zip() {
  local z=$1 pattern=$2 nested=""
  local tmp_prefix=/$TEMPDIR/temp-${LOGNAME}-$pid

  echo ==== $z

  # (1) look inside the zip (top-level)
  # (2) look for nested TAR files - plus,
  search_inside_zip $z

  # (3) look for nested ZIP files. For this, must extract the temp zip
  # file to a file to look inside for other nested tar/zip files.
  for nested in $(unzip -l $z | egrep -v '^Archive' | egrep '\.zip$' | awk '{print $NF}')
  do
    printf "  == $nested\n"
    local tmpzip=${tmp_prefix}__${z##*/}__${nested##*/}
    log_debug "search nested zip: $z/$nested (temp-file: \"$tmpzip\")\n"
    unzip -p $z $nested >  $tmpzip
    chmod a+rw $tmpzip 2>/dev/null   # so that others can delete it if necessary

    search_inside_zip $tmpzip
    [ $keep_tmpzip -eq 0 ] && rm $tmpzip
  done
}

#############################################################################
main() {
  for z
  do
    search_zip $z
    echo
  done
}

main $@


#############################################################################
# tests...
#############################################################################
test_regexp_from_list () {
  echo ==============test_regexp_from_list =============================
  expecting="^one$|^two$|^three$|^four$|^foo.bat$|^foo.bar$"
  printf "\n[$expecting]  <=======expecting\n"
  regexp_from_list -w  one two three four foo{.bat,.bar}

  expecting="one$|two$|three$|four$|foo.bat$|foo.bar$"
  printf "\n[$expecting]  <=======expecting\n"
  regexp_from_list     one two three four foo{.bat,.bar}

  expecting=" one$| two$| three$| four$| foo.bat$| foo.bar$"
  printf "\n[$expecting]   <=======expecting\n"
  regexp_from_list -s  one two three four foo{.bat,.bar}
  
  expecting=" one$| two$| three$| four$| foo.bat$| foo.bar$| foo$"
  printf "\n[$expecting]  <=======expecting\n"
  regexp_from_list -s "$(printf 'one \n\ntwo \n three four \t foo{.bat,.bar,} \n')"
}

do_test() {
  test_regexp_from_list 
}
