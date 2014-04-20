#!/bin/bash
#
# Search for files matching a given regular expression in zip/tar files.
# Pattern is matched against full path of file in archive. Nested archives
# also searched (this requires uncompressing the file to a temp directory).
#
# Used to verify that a distribution zip contains all the necessary parts,
# (including those that seem to go missing from time to time...)

#############################################################################
usage() {  cat<<EOF
  Search for files matching a given pattern in zip/tar files.
  Usage: ${PROG} [-p] [-g] [-h] {zipfile}
   -p {prod}   print files for the given product (oggadp, oggcore,...)
   -g          also search for key OGGCORE executables
   -r {regex}  search for files matching the regular expression
   -h          print usage

  Debug options:
   -a   print all files, not just those matching the pattern
   -k   keep temp zip file (in /\$TEMPDIR/temp-\${LOGNAME}-\$PID)
   -q   quiet (disable verbose)
   -x   keep permissions in output
   -v   more verbose (given twice is more verbose)

  Env vars:
    Set TEMPDIR to something other than /tmp to change where
    temporary zip files are made (TEMPDIR=${TEMPDIR})
EOF
}


#############################################################################
# globals
#############################################################################

PROG=${BASH_SOURCE[0]##*/}       # this program name (basename $0)
PID=$$                           # this process pid (for temp files)
KEEP_TMPZIP=false                # keep temp file after run (/tmp/temp-{user}-{pid}*.zip)
VERBOSE=0                        # -v for verbose, "-v -v" for more verbose
MATCHING=1                       # only print files matching the pattern (default)
PRINT_PERMS=0                    # print unix permissions in output

: ${TEMPDIR:=/tmp}               # default tmp working dir for temp zip files

# Test for list of filenames that *must* exist inside zip/tar files (for oggadp/oggcore).
# Convert list into regexp (eg, "foo.exe bar.dll" => "foo.exe$|bar.dll$")
OGGADP_FILES="flatfilewriter{.so,.dll} gendef{,.exe} ggjava/ggjava.jar libggjava_ue.so libggjava_vam.so ggjava_ue.dll ggjava_vam.dll"
OGGCORE_FILES="replicat{,.exe} logdump{,.exe} extract{,.exe} defgen{,.exe} defgen{,.exe}"

## string patterns (filenames) to verify exist inside zip/tar files.
#CHECK_REGEXP='file.*exe$|file.*so$|file.*dll$|java.*exe|java.*so$|java.*dll$|gendef|ggjava/ggjava.jar$|pdf$'

#############################################################################
log_debug() {
 [ $VERBOSE -ge 1 ] && printf -- "[DEBUG-${VERBOSE}] $@\n"
}

##############################################################################
# Create "or" regexp from given arguments (even if extra whitespace in input).
# Options:
#  -w  match whole words, i.e., "^word$" vs. just "word$" . The default is to just
#      match on word end ("word$"); pattern "bar$" would match "bar" and "foobar"
#  -s  include a blank space at the beginning of the pattern, e.g,  " word$";
#      pattern "bar$" would only match " bar" , not "foobar".
#
# The following return the same pattern:
#  * one two three four foo.bat foo.bar
#  * "one   two\n three\n\n four\n foo.bat  foo.bar"
#  * {one,two} three four foo{.bat,.bar}"
#
regexp_from_list() {
  local input p ws
  local opt OPTIND OPTARG
  local all="." pat='&\$'

  while getopts ws opt; do
    case "$opt" in
      w) pat='^&\$';;
      s) pat=' &\$';;
    esac
  done; shift $((OPTIND-1)); OPTIND=1

  input=$(echo "$*" | tr '\12' ' ')

  all=$(for p in $(eval "echo $input") ; do
           printf "$p" | sed "s/[^ ][^ ]*/|$pat/g"
        done | sed 's/^|//')

  [ "$all" = "" ] && all="."

  echo "$all"
}

#############################################################################
# indent by the given level (default=2); e.g, filter_indent 4
filter_indent() {
  local depth=${1:-2}
  local str=$(for i in $(seq 1 ${depth}); do printf "  "; done)
  sed "s/.*/ $str  & /"
  return 0
}

#############################################################################
# remove "-rw-rw-rw" persmissions from output stream
filter_perms() {
  [ $PRINT_PERMS -eq 0 ] \
    && sed 's/^-[^\/]*[^ ]*//' \
    || cat
  return 0
}

#############################################################################
# Filter and reformat. Grep's for filename pattern(s), and reformats
#  output to strip unix permissions and add indentation
filter_grep() {
  [ $MATCHING -le 1 ] \
    && egrep "$CHECK_REGEXP" | filter_perms | filter_indent \
    || filter_perms | filter_indent
  return 0
}

#############################################################################
test_zip() {
  log_debug "testing zip: $1\n"
  [ $# -lt 1 -o ! -f "$1" ] && echo "** Error: zip archive not found: $1" 1>&2 && return 3
  unzip -q -t "$1" || { echo "** Error: bad zip archive: $1" 1>&2; return 3; }
  return 0
}

#############################################################################
# Search through the zip for embedded tar files; then search tar for files
# matching the pattern. Note that this one doesn't look for zip files inside
# tar files; rather, it just looks for tar files insize zip files.
# Usage: search_inside_zip {tar...}
#
search_inside_zip() {
  local  tarball zp=$1

  log_debug "(begin) search_inside_zip: $zp\n"
  test_zip "$zp" || return 3

  # look at the top level of the archive for files
  unzip -l $zp | filter_grep

  for tarball in $(unzip -l "$zp" | egrep '\.tar$' | awk '{ print $NF }')
  do
    printf "  == $tarball\n"
    unzip -p "$zp" "$tarball" | tar -tvf - | filter_grep
  done
  log_debug "(done) search_inside_zip: $zp\n"
}

#############################################################################
# List contents of archive & nested archives, searching for files matching
# the given pattern.  Usage: search_zip {zipfile} {regexp_pattern}
#
search_zip() {
  local ret=0 zp=$1 pattern=$2
  local nested
  local tmp_prefix=/$TEMPDIR/temp-${LOGNAME}-$PID

  echo "==== $zp"

  # (1) look inside the zip (top-level)
  # (2) look for nested TAR files ...
  search_inside_zip $zp

  # (3) look for nested ZIP files. For this, must extract the temp zip
  #     file to look inside for other nested tar/zip files.
  for nested in $(unzip -l $zp | egrep -v '^Archive' | egrep '\.zip$' | awk '{print $NF}')
  do
    printf "  == $nested\n"
    local tmpzip=${tmp_prefix}__${zp##*/}__${nested##*/}
    log_debug "search nested zip: $zp/$nested (temp-file: \"$tmpzip\")\n"
    unzip -p $zp $nested >  $tmpzip
    chmod a+rw $tmpzip 2>/dev/null   # so that others can delete it if necessary

    search_inside_zip $tmpzip
    $KEEP_TMPZIP || rm $tmpzip
  done
  echo
  return $ret # not actually set
}

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

#############################################################################
# main
#
search_archive() {
  local ret=1 zp opt OPTIND OPTARG

  while getopts aghkp:qr:vx opt; do
    case "$opt" in
      a) # print all files, not just those matching the pattern
         MATCHING=2
         ;;
      g) # search for oggadp files and oggcore (important) files
         CHECK_REGEXP=$(regexp_from_list $OGGADP_FILES $OGGCORE_FILES)
         ;;
      h) usage
         exit 2
         ;;
      k) # keep temp file
         KEEP_TMPZIP=true
         ;;
      x) # also print file perm's (rwx-r-x---)
         PRINT_PERMS=1
         ;;
      p) # print the given product artifacts...
         case "$OPTARG" in
           oggadp) CHECK_REGEXP=$(regexp_from_list $OGGADP_FILES)
            ;;
           oggcore) CHECK_REGEXP=$(regexp_from_list $OGGCORE_FILES)
            ;; 
           all) CHECK_REGEXP=$(regexp_from_list $OGGADP_FILES $OGGCORE_FILES)
            ;;
           *) printf "** error: unknown product\n"; return 2
            ;; 
         esac
         ;;
      q) # print more info
         VERBOSE=0
         ;;
      r) # use the given regexp
         CHECK_REGEXP="$OPTARG"
         ;;
      v) # print more info... use multiple's for more
         (( VERBOSE ++ ))
         ;;
     *) echo "unknown option ($*)" 1>&2
         usage
         exit 2
         ;;
    esac
  done; shift $((OPTIND-1)); OPTIND=1

  [ $VERBOSE -gt 0 ] && echo "search for files: \"$CHECK_REGEXP\""

  #return 0

  for zp ; do
    search_zip $zp && ret=0
  done
  return $ret
}

# default regexp
CHECK_REGEXP=$(regexp_from_list $OGGADP_FILES)

search_archive "$@"

