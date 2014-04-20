#!/bin/bash

########################################################################
# Try to create meaningful filenames from pdf product documentation,
# looking at file contents & metadata, and creating a symlink
# from this new name back to the original file.
########################################################################

# (Hacked up to try to find meaningful names/titles from Oracle product docs)


default_outdir=links

usage() {
  local ret=0
  [ $# -gt 0 ] && ret=2 && printf "** error: $@  (...exiting).\n\n" 1>&2 && printf " Usage: \n"

  cat <<USAGE_EOF
  Print out titles for given pdf documents, pulling metadata to generate the
  names, optinally creating symlinks back to the original file.

  By default, just prints metadata, doesn't overwrite/create any files.
  Use "-a" to create plain text files for the pdf and make the symbolic links.

  Usage: $(basename $0) pdf_file

  Options:
     -a   sets a common set of all useful defaults: -f -l -t -x -d $default_outdir
     -d   output directory for links, text files (default="${outdir:-$default_outdir}")
     -f   include original filename in title (default=no) (required if using "-l", to avoid clashes)
     -l   create symlinks from original pdf file to longer filename (default=no) (requires also "-f")
     -i   create symlinks, ask before overwriting
     -t   create text file from pdf (same name as pdf, using txt extension).
     -x   try harder to make a meaningful, longer title (searches through pdf)
     -v   verbose

  Examples:
      $(basename $0) -a *.pdf
      $(basename $0) -a -d links *.pdf

USAGE_EOF
  [ $ret -gt 0 ] && exit $ret || return $ret
}

get_sfx() {
  #printf "get suffix from: $1\n\n" 1>&2
  f="$1"
  b="${f%.*}"
  sfx=${f/$b/}
  sfx="${sfx#.*}"
  echo $sfx
}

log() {
  [ $verbose != "0" ] && echo "** $@"
  return 0
}

########################################################################
# main
########################################################################
[ $# -eq 0 ] && usage "expecting arguments"
type pdftk >/dev/null 2>&1 || usage "pdftk utility not installed / not found in the PATH. pdftk is required"
type tr    >/dev/null 2>&1 || usage "'tr' utility not found. 'tr' is required"
printf "foo\nbar" |tr -d '\12' |grep foobar > /dev/null || usage "compatible 'tr' not found ('tr -d' unsupported?)"

do_link=0
do_filename=0
do_try=0
verbose=0
do_ask=0
ln_opts="-s"
outdir=$default_outdir

## set debug=1 to disable linking
debug=0
#debug=1
[ "$debug" = "1" ] && run=echo || run=
[ "$debug" = "1" ] && echo "## ***** WARNING:  debug mode enabled, not Creating any files ******" 1>&2

OPTIND=1
while getopts ad:filtvx opt ; do
  case "$opt" in
  a)
    do_filename=1    &&  log "info: (-f) include original filename in new file."
    do_link=1        &&  log "info: (-l) create symbolic links"
    do_text=1        &&  log "info: (-t) generate text file"
    do_try=1         &&  log "info: (-x) search pdf for a better title (level=$do_try)"
    outdir=$default_outdir &&  log "info: (-d $outdir) create links/files in directory"
    echo "** setting options for -a => -f -l -t -x -d $outdir"
    ;;

  d)
    default_outdir=${OPTARG}
    outdir=${OPTARG} &&  echo "** create output in directory: $outdir"
    ;;

  f)
    do_filename=1    && log "info: including original filename in resulting file."
    ;;

  i)
    log "info: creating symbolic links (asking before overwriting)"
    ln_opts="-i -s"
    do_ask=1
    ;;

  l)
    log "info: creating symbolic links (also setting '-f')"
    do_link=1
    do_filename=1
    ;;

  t)
    do_text=1       &&  log "info: generate text file"
    type pdftotext >/dev/null 2>&1 || usage "pdftotext is not found. pdftotext is to use '-t' option"
    ;;

  x)
    (( do_try = do_try + 1 ))
    log "warning: will search through pdf to generate a better pdf title (level=$do_try)"
    ;;

  v)
    echo "** info: verbose enabled"
    verbose=1
    ;;

  h)
    usage && exit 0
    ;;

  *)
    usage "** unknown option, $opt"
    ;;
  esac
done; shift $((OPTIND-1)); OPTIND=1

[ "$do_link" = "0" ] \
    && printf "** [warning] Not creating links, just printing pdf info to stdout (use '-h' for full usage).\n\n"

[ "$do_link" = "1" -a "$do_filename" = "0" ] \
    && printf "** [warning] Links won't be created unless '-f' is also specified.\n\n"

for file
do
  [ ! -f "$file" ] \
    && echo "** error: pdf file not readable: $( file $file )" \
    && exit 2
  [ $(get_sfx "$file") != "pdf" ] \
    && echo "** error: file is not pdf (extension must be 'pdf'): $file   $( file $file )" \
    && exit 2
done

for file
do
  if [ "$verbose" = "1" ]; then     # print verbose pdf metadata info
    echo pdftk $file dump_data
    pdftk $file dump_data \
    | egrep '^InfoKey|InfoValue' \
    | sed 's/InfoValue: */=/' \
    | tr -d '\12' \
    | sed 's/InfoKey:/\n/g'
  fi

  # extended pdf filename
  efname=$(pdftk $file dump_data \
    | egrep '^InfoKey|InfoValue' \
    | sed 's/InfoValue: */=/' \
    | tr -d '\12' \
    | sed 's/InfoKey:/\n/g' \
    | egrep '^ *Title=' \
    | sed 's/^ *Title=//; s/  */_/g; s/[#0-9*&;:]//g' \
    | sed 's/[-_]*Microsoft.Word[-_]*//g' \
    | sed 's/_[-_.]*_/-/g' | tr -d '["]'  | tr -d "[']"  | tr '[/.]' '-' | sed 's/--*/-/g; s/-_/-/g; s/_-/-/g; s/doc-doc/doc/g' )


  # try to get rid of all goofy characters to create a reasonable filename for the symlink
  if [ $do_try -gt 0 ]; then
     # change Oracle to OracleX to leave oracle in the filenames
     efname3=$(echo $(pdftotext $file - | sed '/^ *$/q' | head -5 | sed "N; s/\n/_/g; s/[ ]\{1,\}/-/g" ))
     efname4=$(echo "$efname3" | sed 's/[^-a-zA-Z0-9._]\{1,\}/_/g; s/[-_.][-_.]\{1,\}/_/g' )
     efname5=$(echo "$efname4" | sed 's/^OracleX[-_]*GoldenGate[-_]*//; s/^for[-_]*//; s/^OracleX[-_]*//; s/^\([A-Z]\)-/\1/; s/^[-_.]*//; s/[-_.]*$//' )
     efname6=$(echo "$efname5" | sed 's/^\([A-Z]\)-/\1/; s/[-_]s[-_]/s-/g; s/^[-_.]*//; s/[-_.]*$//' )
     #printf "** info: try for longer title [a](was: $efname) => \"$efname5\"\n"
     #printf "** info: try for longer title [z](was: $efname) => \"$efname6\"\n"

     efname="$efname6"
  fi

  # Optionally, include original filename in new filename. Linking is enabled
  # only if original filename is in link name (for safety, to guarantee unique names)
  if [ "$do_filename" = "1" ]; then
    dir=$(dirname $file)
    [ $dir = "." ] && dir="" || dir=${dir}/
    [ "${efname}" = "" ] && efname=doc

    efname_len=${#efname}
    [ $efname_len -gt 140 ] \
         && printf "** [warning] name too long (len=$efname_len); $efname\n** warning: truncating name to 140 chars\n\n" \
         && efname="${efname:0:140}"

    efname=$(basename $file .pdf)-${efname}.pdf       #efname=${dir}$(basename $file .pdf)-${efname}.pdf
    log "** debug: long name (len=$efname_len): $efname\n"

    if [ "$do_link" = "1" ]; then
      log "info: using full paths for links"
      outdir_rel=$PWD

      [ "$verbose" = "1" ] && printf "** info: outdir=$outdir
       ** outdir_rel=$outdir_rel
       ** file=$file
       ** orig_file=$orig_file \n"

      link_file="$efname"
      orig_file="$outdir_rel"/"$file"

      # don't link if pdf is already a link, or extended filename is same as pdf
      if [ ! -h "$file" -o "$file" = "$efname" ]; then
         [ ! -d $outdir ] && $run mkdir -p $outdir
         echo "linking: ln $ln_opts $orig_file $link_file" 1>&2
         ( $run cd $outdir && $run ln $ln_opts "$orig_file" "$link_file" && $run cd - >/dev/null)
      fi
    fi
  else
    printf "$efname\n"
  fi

  if [ "$do_text" = "1" ]; then
    [ ! -d "$outdir" ] && $run mkdir -p "$outdir"
    out=${outdir}/$(basename ${efname} .pdf).txt
    if [ -f "$out" ]; then
      [ "$do_ask" = "1" ] && echo "file exists: " && rm -i "$out"
      [ "$do_ask" = "0" ] && echo "file exists, overwriting: $out" && rm "$out"
    fi

    echo "** creating output file: $out"
    [ ! -f "$out" ] && $run pdftotext $file $out      # pdftotext $file - > $out
    echo ===========================
  fi

done

