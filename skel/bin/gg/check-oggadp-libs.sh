#!/bin/bash
#
# Given a zip file, search for files in that zip. A listing of the archive
# contents is generated, and the output is "grep'd" through to match a given
# list of files. The file list is converted into a regular expression.
#
# In addition, nested zip/tar files are also searched (e.g., for searching
# for files in OGG distro's)
#

prog=${BASH_SOURCE[0]##*/}  # this program name (basename $0)
pid=$$                 # this process pid (for temp files)

# filenames that must exist inside zip/tar files (not necessarily all files,
# just the files that have a tendency to go missing without notice....)
oggadp_filelist="flatfilewriter{.so,.dll} filewriter{.so,.dll} gendef{,.exe} ggjava/ggjava.jar libggjava_ue.so libggjava_vam.so ggjava_ue.dll ggjava_vam.dll"
oggcore_filelist="replicat{,.exe} logdump{,.exe} extract{,.exe} defgen{,.exe} defgen{,.exe}"

# final filelist will be converted into a regexp (eg, "foo.exe bar.dll" => " foo.exe$| bar.dll$")
search_pattern=""

quiet=0                # if quiet=1, be very quiet, only print file matches (NOT the default)

regexp_opts=""         # constructing the regexp from the filelist
print_perms=0          # print unix permissions in output

# debug:
verbose=0              # '-v' for verbose, set "-v -v" for more verbose
delete_tempzip=1       # optionally keep temp zip's after run (/tmp/temp-{user}-{pid}*.zip)

TEMP_DIR=${TEMP_DIR:-/tmp} # override default tmp working dir for temp zip files


#############################################################################
# Running with no arguments:
#  $ check-oggadp-libs.sh ggs_Adapters_Linux_x64.zip
#  ==== ggs_Adapters_Linux_x64.zip
#    == ggs_Adapters_Linux_x64.tar
#          341028 2012-06-12 10:14 flatfilewriter.so
#          304404 2012-06-12 10:14 gendef
#            8830 2012-03-22 02:21 ggjava/ggjava.jar
#           203942 2012-06-12 10:14 libggjava_ue.so
#           319183 2012-06-12 10:14 libggjava_vam.so
#
#  $ check-oggadp-libs.sh ggs_Adapters_Windows_x64.zip
#   ==== ggs_Adapters_Windows_x64.zip
#    No errors detected in compressed data of ggs_Adapters_Windows_x64.zip.
#
#              392704  2012-06-12 10:21   flatfilewriter.dll
#                8830  2012-03-22 02:21   ggjava/ggjava.jar
#              245760  2012-06-12 10:22   ggjava_ue.dll
#              363520  2012-06-12 10:22   ggjava_vam.dll
#      == ggjava/docs/javadoc.zip
#    No errors detected in compressed data of /tmp/temp-msnielse-22312__ggs_Adapters_Windows_x64.zip__javadoc.zip.
#
#
#
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
  cat<<EOF

     Search the contents of a zip file for files matching a given pattern.
     Looks at nested zip's and tar's inside the given zip file(s) (e.g., OGG dist's).

     Usage: ${prog} {options} [filenames] {zipfiles}

     Options and arguments:
       [filenames] - a list of files to search for (optional). By default searches
                      for the main OGGADP files to verify they exist in the archive.

       {zipfiles}  - a list of zip files (OGG distro's) to search.

        -a    - search for main OGGADP files (default)

        -g    - search for main OGGCORE files (use with -a to also search for OGGADP)

        -h    - print usage

        -e    - allow a regexp to be specfied. If given a list of filenames, they
                are converted to an "or" reg expression (e.g., "one|two|three")

     Rather than using the predefined list of files for OGGADP and OGGCORE, the search
     pattern can be specified. To search only for the following files in the given zip's:
         $ ${prog} extract gendef defgen flatfilewriter.{dll,so} ggs_Adapters_*_x64.zip

     Instead of listing filenames, a regular expression can be given (using "-e {pattern}"):
         $ ${prog} -e '^extract$|^gendef$|flatfilewriter'  ggs_Adapters_*_x64.zip

     Debug-only options:
        -p  - print permissions from tar file listing
        -k  - keep generated temp zip files (by default, in /tmp/temp-${LOGNAME}-{pid}*.zip)
        -v  - verbose (use option twice to be more verbose)

     Environmental variables:
         Set TEMP_DIR to something other than /tmp (default) to change directory
         where temporary zip files are made (currently, TEMP_DIR=${TEMP_DIR}).
EOF
}

#############################################################################
log_debug() {
 #[ $verbose -ge 1 ] && printf -- "[DEBUG] $@\n"
 [ $verbose -ge 1 ] && printf -- "[DEBUG-($verbose)] $@\n"
}


##############################################################################
# For all given arguments, create "or" regexp with a space before and an
# anchor at the end.  For example, given "a b" creates " a$| b$"
#
# This is to help search via regexp for a file in an archive listing, e.g.,
#         392704  2012-06-12 10:21   flatfilewriter.dll
#           8830  2012-03-22 02:21   ggjava/ggjava.jar
#         245760  2012-06-12 10:22   ggjava_ue.dll
#         363520  2012-06-12 10:22   ggjava_vam.dll
#
# This listing can easily be grep'd for:  " ggjava/ggjava.jar$| ggjava_ue.dll$"
#
# Options:
#   -e   use exact string, no anchors: given "one two" return "one|two"
#   -s   no space added at start of pattern: return "word$", not " word$"
#   -w   match whole words (implies "-s"): return "^word$", not " word$"
#
# Example:
#  $ regexp_from_list -w one two three four foo.bat foo.bar
#    "^one$|^two$|^three$|^four$|^foo.bat$|^foo.bar$"
#
#  $ regexp_from_list    one two three four foo.bat foo.bar
#    " one$| two$| three$| four$| foo.bat$| foo.bar$"
#
#  $ regexp_from_list -s one two three four foo{.bat,.bar}
#    "one$|two$|three$|four$|foo.bat$|foo.bar$"
#
# The following would return the same string:
#  *  one two three four foo.bat foo.bar
#  *  "one   two\n three\n\n four\n foo.bat  foo.bar"
#  *  {one,two} three four foo{.bat,.bar}"
#
regexp_from_list() {
  local opt OPTIND OPTARG
  local all="." pat=' &\$' args="$@"

  while getopts esw opt; do
    case "$opt" in
      w) pat='^&\$' ;;
      s) pat='&\$' ;;
      e) pat='&' ;;
      *) printf "** warning: ${FUNCNAME}: unknown option ($*)\n" 1>&2;;
    esac
  done; shift $((OPTIND-1)); OPTIND=1

  local input=$(echo "$*" | tr '\12' ' ' | tr '|' ' ')

  all=$(for p in $(eval "echo $input")
        do
           printf "$p" | sed "s/[^ ][^ ]*/|$pat/g"
        done | sed 's/^|//; s/\$\$*/$/g; s/\^\^*/^/g')

  [ "$all" = "" ] && all="."

  echo "$all"
  return 0
}


#############################################################################
# indent by the given level (default=2). E.g., filter_indent 4
filter_indent() {
  local str="" depth=${1:-0}

  [ $depth -eq 0 -a $quiet -eq 0 ] && depth=4
  [ $quiet -eq 1 ] && depth=0

  [ $depth -gt 0 ] \
     && str=$(for i in $(seq 1 ${depth}); do printf "  "; done) \
     && sed "s/.*/${str}&/" \
     || cat

  return 0
}

#############################################################################
# remove "-rw-rw-rw" persmissions from output stream
filter_perms() {
  [ $print_perms -eq 0 ] \
    && sed 's/^-[^\/]*[^ ]*//' \
    || cat
  return 0
}

# remove file sizes and dates and just leave filenames
filter_fileinfo() {
  [ $quiet -eq 1 ] \
    && sed "s/^[- 0-9:]*//" \
    || cat
  return 0
}

# remove irrelevant "./" prefix from filenames
filter_slashdot() {
  sed "s/ \.\// /"
  return 0
}

#############################################################################
# Filter and reformat. Grep's for filename pattern(s), and reformats
#  output to strip unix permissions and add indentation
filter_grep() {
  local pattern="$1"
  [ $verbose -le 1 ] \
    && filter_slashdot | egrep "$pattern" | filter_perms | filter_fileinfo \
    || filter_slashdot | filter_perms | filter_fileinfo
  return 0
}

#############################################################################
test_zip() {
  local z=$1 msg=""
  log_debug "testing zip: $z\n"

  [ $# -lt 1 -o ! -f "$z" ] \
     && printf "** Error: zip archive not found: $z\n" 1>&2 \
     && return 3

  msg=$(unzip -q -t "$z" 2>&1) \
     || { printf "** Error: bad archive: $z\n** $msg\n" 1>&2; return 3; }

  [ $verbose -gt 0 ] \
     && printf "$msg\n"

  return 0
}

#############################################################################
# Search through given zip file for nested tar files, then search
# through the tar file's contents using a regexp.
# Usage: search_inside_zip [-z] {tar...}
#     -z  (not implemented) explicitly gunzip'ed tar if necessary
#         (not usually necessary; gnu tar can figure this out on its own)
#
# Note that we don't look for zip files inside tar files; we only look for
# tar files insize zip files.
#
search_inside_zip() {
  local z=$1 pattern=$2 tarball=""

  log_debug "search_inside_zip: \"$z\"\n"
  log_debug "using search pattern: \"$pattern\"\n"

  test_zip "$z" || return 3

  # look at the top level of the archive for files
  unzip -l $z | egrep -v '^Archive:' | filter_grep "$pattern"| filter_indent 2

  for tarball in $(unzip -l "$z" | egrep '\.tar$' | awk '{ print $NF }')
  do
    is_verbose && printf "  == search nested tar: $tarball\n"
    unzip -p "$z" "$tarball" | tar -tvf - | filter_grep "$pattern"| filter_indent 4
  done
}

#############################################################################
# List contents of nested zip file(s), search for files matching patterns.
# if there is a nested zip or tar, also search through those.
#   Usage: search_zip {zipfile} {regexp_pattern}
#
search_zip() {
  local z=$1 pattern=$2 nested=""
  local tmp_prefix=$TEMP_DIR/temp-${LOGNAME}-$pid

  is_verbose && printf "==== search $z\n"

  # (1) given a zip, search this zip for the list of files (top-level only)
  # (2) also look for nested TAR files, and search inside them

  search_inside_zip "$z" "$pattern"

  # (3) next, look for nested ZIP files and search inside them (must unzip to tmp file)
  for nested in $(unzip -l $z | egrep -v '^Archive:' | egrep '\.zip$' | awk '{print $NF}')
  do
    is_verbose && printf "  == search nested zip: $nested\n"
    local tmpzip=${tmp_prefix}__${z##*/}__${nested##*/}
    log_debug "search nested zip: \"$z\"/\"$nested\" (temp-file: \"$tmpzip\")\n"
    unzip -p $z $nested >  $tmpzip
    chmod a+rw $tmpzip 2>/dev/null   # allow anyone to delete (if necessary)

    search_inside_zip "$tmpzip" "$pattern"

    [ $delete_tempzip -eq 1 ] && rm "$tmpzip"
  done
}

is_quiet() {
  [ $quiet -eq 1 ]
}
is_verbose() {
  [ $quiet -eq 0 ]
}

#############################################################################
# By default search for files in $oggadp_filelist (or $oggcore_filelist).
# Allow giving the list of files to search for on the cmdline, in addition
# to zip files. If given "--", assume rest of files are zipfiles.
#
main_prog() {
  local opt OPTIND OPTARG
  local new_search_list=""
  local zip_list=""
  local only_archives_remain=0
  local search_list=""

  while getopts aghkpqvesw  opt; do
    case "$opt" in
      a) search_list="$search_list $oggadp_filelist" ;;
      g) search_list="$search_list $oggcore_filelist" ;;
      h) usage; return 2 ;;
      k) delete_tempzip=0 ;;
      p) print_perms=1 ;;
      q) verbose=0; quiet=1 ;;
      v) (( verbose ++ )) ;;
      e|s|w) # pass to regexp_from_list
         regexp_opts="$regexp_opts -${opt}" ;;
      *) printf "** error: unknown option ($*)\n" 1>&2
         usage
         return 2
         ;;
    esac
  done; shift $((OPTIND-1)); OPTIND=1
  
  [ "$search_list" = "" ] && search_list=$oggadp_filelist
  search_pattern=$(regexp_from_list $search_list)
  
  log_debug "** searching for files (default): \"$search_list\"\n"
  log_debug "** regular expresion (default): \"$search_pattern\"\n"
  
  # Separate cmdline args into zip's & the files we're searching for.
  for arg
  do
    [ "$arg" = "--" ] && only_archives_remain=1 && continue
    [ $only_archives_remain -eq 1 -o "${arg##*.}" = "zip" ] \
        && zip_list="$(echo $zip_list $arg)" \
        || new_search_list="$(echo $new_search_list $arg)"
  done
  
  log_debug "** files to search for: ${new_search_list:-"(none)"}\n"
  log_debug "** zip files: ${zip_list:-"(none)"}\n"
  
  [ "$new_search_list" != "" ] \
    && old_search_pattern="$search_pattern" \
    && search_pattern=$(regexp_from_list $regexp_opts $new_search_list) \
    && is_verbose \
    && printf "** checking for files (list): \"$search_list\"\n" \
    && printf "** checking for files (pattern): \"$search_pattern\"\n" \
    && printf "** searech zip file(s): $zip_list\n\n"
  
  for zipfile in ${zip_list}; do
     search_zip $zipfile "$search_pattern"
  done

  return 0
}

main_prog "$@"


