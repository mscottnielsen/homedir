#!/bin/bash
############################################################################
# Usage: ext2dir {archive.suffix} [{archive2.suffix2}...]
#  Extracts/unzips an archive into a directory with the same name as the archive.
#  Based on filename suffix, chooses the correct tool to extract/unzip/untar the file.
#  If the top-level archive contains archives, those are also extracted.
#  If duplicate subdirectories are created with the same name, those are removed;
#  for example, "foo/foo/file1.txt" will be restructured as "foo/file1.txt".
#
# Returns true if something was extracted, else false.
#
# Example #1: Given an archive foo.tgz which contains dir1/dir2/file.txt,
#  then 'ext2dir foo.tgz' will create: foo/dir1/dir2/file.txt.
#
# Example #2: Given an archive "foo.tar.gz" which contains "bar.zip", which in turn
#   contains "dir1/dir2/file.txt" then running "ext2dir foo.tar.gz" will create:
#     ${PWD}
#        |--foo.tar.gz
#        |--foo/
#            |--bar.zip
#            |--bar/
#                |--dir1/dir2/file.txt
#
# Example #3: Given an archive "foo.tgz" which contains "bar.zip", which in turn
#   contains baz.zip which contains "dir1/dir2/file.txt"... then running "ext2dir foo.tgz"
#   will create:
#     ${PWD}
#        |--foo.tgz
#        |--foo/
#            |--bar.zip
#            |--bar/
#                |--baz.zip (baz.zip not extracted)
#
# Notes:
#  * only top-level nested archives are decompressed (one level deep).
#  * the original archive is always preserved; if the archive is a gzip or bzip
#    file, the original file is preserved by copying it (a "preserve" option
#    could be used, if possible both cross-version & cross-platform)
#
############################################################################


##########################################################################
# After expanding foo.tgz, if dir is: foo/foo/{file1,file2,...} then
# trim the top-level "foo"
#
# For example, given foo.tgz that explodes to (bar2 and bla3 are unrelated):
#   parent
#     |--foo/           # created by ext2dir from foo.tgz
#         |--foo/       # from foo.tgz => foo.tgz/foo
#         |   |--bar    # from foo.tgz => foo.tgz/foo/bar
#         |   |--foo    # from foo.tgz => foo.tgz/foo/foo
#         |...
#         |--bar2       # somehow created at some point, e.g.
#         |--bla3       # from ext2dir or from other archives
#
# rename the dupe dir (could have another same-name subdir)
#   parent
#     |--foo/
#         |--foo.1234/
#         |   |--bar
#         |   |--foo
#         |...
#         |--bar2
#         |--bla3
#
# move subdirs up:
#   parent
#     |--foo/
#         |--foo.1234/
#         |--bar
#         |--foo
#         |...
#         |--bar2
#         |--bla3
#
# and remove the tmp dir
#   parent
#     |--foo/
#         |--bar
#         |--foo
#         |...
#         |--bar2
#         |--bla3
#
#
#################################################################################
# De-duplicate directories; give either a filename like "foo.tar.gz"
# or "foo.zip", or simply a directory like "foo". In either case, will
# look in pwd to convert "foo/foo/*" into "foo/*".
#
de_duplicate() { # {{{1
  local suffix dir tmp_dir file tmp_file ret=0

  #printf "\n== de_duplicate: allow dupes? $allow_dup_dir  args: $@\n"
  [ $# -eq 0 -o "$allow_dup_dir" = "true" ] && return 0
  #printf "** removing duplicate dirs for files: $@\n"

  for arg
  do
    if [ -f $arg ]; then
      suffix=$(get_suffix "$arg")
      dir=$(basename $arg .${suffix})
    else
      dir=$arg
    fi

    dir_dir="${dir}/${dir}"
    tmp_dir="${dir}/${dir}.$$"

    #printf "\n==pwd: $(pwd)\n De-duplicate directory: $dir\n"
    #printf " test: $(file "$dir_dir")\n"  #> /dev/null

    if [ -d "$dir_dir" ]; then
      printf " ** remove duplicate directory: $dir_dir\n" > /dev/null
      [ -d "$tmp_dir" ] \
        && ( printf "** temp directory already exists: $tmp_dir" 1>&2 ; return 2; )

      mv "$dir_dir" "$tmp_dir" \
        || ( printf "** unable to rename to temp dir: $dir_dir =to=> $tmp_dir" 1>&2 ; return 2; )

      for tmp_file in "$tmp_dir"/* "$tmp_dir"/.??*
      do
        if [ -e "$tmp_file" ] ; then
           #printf "*** moving from subdir: $(basename $tmp_file)\n"
           #printf "      moving: $tmp_file =to=> $dir\n"
           mv -i "$tmp_file" "$dir"
        fi
      done
      #printf "     any files remain? : $(ls -lA "$tmp_dir")"
      #printf " ** removing subdirectory $dir_dir\n"
      rmdir "$tmp_dir"
    else
      :
      # printf "  == no duplicate directory: $dir_dir\n"
    fi

  done
} # }}}

usage() {
  cat <<USAGE_EOF

  Usage: ${BASH_SOURCE[0]##*/} {archive...}
    Extracts any archive file into a directory having the same name as the
    archive.  Also extracts any top-level nested archives as well.
    Removes meaningless duplicate directories as well.
    Works with achive types {zip, tar, tar.gz, rar, jar, 7z, ...}

    Examples:
      Given foo.zip, containing bar/file* extract to foo/bar/file*.
      Given foo.tgz, containing foo/file* extract to foo/file*.
      Given foo.zip, containing bar.tar,  containing baz/*, extract to foo/bar/baz/*

USAGE_EOF
  return 0
}

# given a filename, return the suffix
get_suffix() {
  local file=$1
  local suffix=${file##*.}
  [ "${file%%.tar.$suffix}.tar.$suffix" = "$file" ] && suffix="tar.${suffix}"
  echo "$suffix"
}

ext2dir () {
  local use_copy=false        # copy archive to decompress, leaving original intact
  local exploder=             # utility to use to decompress (tar, jar, gzip, bzip2, ...)
  local suffix=               # gz, tar, jar, tar.gz (w/o ".")
  local args=                 # only required if exploder takes args after options
  local opts=                 # command-line options to exploder for extraction
  local ls_opts=              # command-line options to exploder for listing contents
  local dir=                  # dir to extract into: basename of archive (w/o suffix)
  local mytar=                # prefer gnu tar, if exists
  type gtar >/dev/null 2>&1 && mytar=gtar || mytar=tar

  # nested archives to expand (if inside another archive)
  local expand_L2="*.zip *.ZIP *.jar *.tgz *.bz2 *.7z* *.7Z* *.gz *.GZ *.tar *.TAR *.odm *.ott *.rar"

  ##########################################################################
  # do list contents of archive (top level, only)
  do_list() { # {{{1
     [ $# -eq 0 ] && return 1
     # by default use global variables "ls_opts" and "args", unless given arguments
     f=$1 && shift
     [ $# -gt 0 ] && ls_opts=$1 && shift
     [ $# -gt 0 ] && args="$@"

     extfile=$f
     #echo "** Running: $exploder $ls_opts $extfile $args"
     $exploder $ls_opts $extfile $args
  } #}}}

  ##########################################################################
  # Decompress the given file, leaving the original file intact, using the
  # given options and arguments. Uses the current value of "exploder" to
  # perform the decompression. Extracts the file into the directory "$dir".
  #   Usage: do_extract {file} [opts] [args...]
  #
  do_extract() { # {{{1
     [ $# -eq 0 ] && return 1

     # by default, don't copy; otherwise, is set to "cp" if necessary to copy an
     # archive to avoid a destructive operation (e.g., gunzip on a gz file)
     do_copy_cmd="echo"
     do_copy_arg=""

     # by default use global variables "opts" and "args", unless given arguments
     f=$1 && shift
     [ $# -gt 0 ] && opts=$1 && shift
     [ $# -gt 0 ] && args="$@"

     extfile="../$f"
     [ "$use_copy" = "true" ] && do_copy_cmd="cp" && do_copy_arg="." && extfile=$f

     # copying is expensive, (hard) linking isn't always an option
     # (gzip error: "${extfile}.gz has 1 other link  -- unchanged")
     # [ "$use_copy" = "true" ] && do_copy_cmd="ln" && do_copy_arg="." && extfile=$f

     mkdir -p "$dir"
     test -d "$dir" \
       && cd "$dir" > /dev/null \
       && printf "==Extracting $f\n" \
       && printf " Created directory: \"$dir\"\n" \
       || printf "** error creating directory \"$dir\"\n" 1>&2

     $do_copy_cmd "../$f" $do_copy_arg   > /dev/null  \
       && $exploder $opts $extfile $args > /dev/null  \
       && cd -                           > /dev/null  \
       && printf " Extracted file ($exploder) \"$f\" into \"$dir\"\n"  \
       || printf "** error extracting file ($exploder) \"$f\" into \"$dir\"\n" 1>&2

     test -d "$dir"
  } # }}}


  ##########################################################################
  # main:
  #   for each archive, extract it into a subdirectory of the same name.
  #   if result looks like foo/foo/{bar...}, remove the top-level dir.
  ##########################################################################

  for file
  do
    [ ! -f "$file" ] && printf "** File does not exist (skipping): \"$file\"\n" 1>&2 && continue
    exploder=
    opts=
    ls_opts=
    args=
    suffix=$(get_suffix "$file")
    basefile=${file%%.$suffix}
    dir=$(basename $file .${suffix})

    # sanity check: truncate certain extensions from the output directory:
    # given file "foo.txt.gz" => use dir "foo", not "foo.txt";
    # given file "bar.dll.pdf.txt.gz" use dir "bar".
    ext_list=($(printf $(echo "$dir" | sed 's/\./\\n/g') \
       | egrep -i '[a-z]ar$|bak$|ddl$|dll$|html$|log$|pdf$|txt$|sh$|so$|sql$|xml$'))

    # (requires 'seq'... todo: work-around if 'seq' not found.)
    type seq > /dev/null 2>&1 \
      && for ext in $(seq $((${#ext_list[@]} -1 )) -1 0); do
           dir=$(printf "${dir}\n" | sed "s/\.${ext_list[$ext]}$//;")
         done

    #echo "#[debug] create dir=$dir, basefile=$basefile, suffix=$suffix"

    case "$suffix" in
      zip | ZIP | ot? | od? | oxt | xpi)    # zip, OpenDocument (odp,odm,odt,ott,otp...)
        exploder="unzip"
        opts=
        ls_opts="-l"
        ;;
      jar | war | ear)                      # java archives
        exploder="jar"
        opts="-xvf"
        ls_opts="-tvf"
        ;;
      tar | TAR)                            # older tar won't accept "-" on options
        exploder=$mytar
        opts="xf"
        ls_opts="tf"
        ;;
      tar.gz | TAR.GZ | tgz | TGZ)          # assume gnu tar (implements gzip)
        exploder=$mytar
        opts="xzf"
        ls_opts="tzf"
        ;;
      tar.bz2)                              # assume gnu tar (implements bzip2)
        exploder=$mytar
        opts="xjf"
        ls_opts="tjf"
        ;;
      gz | GZ)                              # at this point should't be tar.gz
        exploder="gzip"
        opts="-d"
        ls_opts="-l"
        use_copy=true
        ;;
      bz2)                                  # at this point should't be tar.bz2
        exploder="bzip2"
        opts="-d"
        ls_opts="-t"                        # bzip isn't an archiver, nothing to list; can test.
        use_copy=true
        ;;
      xz)
        exploder="xz"
        opts="-d"
        ls_opts="-l"
        use_copy=true
        ;;
      rar)
        exploder="unrar"
        opts="x"
        ls_opts="l"
        ;;
      *7z | *7z* | *7Z*)      # 7-zip (extension can be 7z.{part}, but extract first file only)
        exploder="7z"
        opts="x"
        ls_opts="l"
        ;;
      tar.Z)                  # compressed tar (use gzip instead of uncompress/zcat/etc)
        exploder=$mytar
        opts="xzf"
        ls_opts="tzf"
        ;;
      Z)                      # compressed file (use gzip instead of uncompress/zcat/etc)
        exploder="gzip"
        opts="-d"
        ls_opts="-l"
        use_copy=true
        ;;
      *)                      # one last check ... zip's often have non-standard extensions
        if file "$file" | egrep -i 'zip archive|OpenDocument' >/dev/null
        then
          exploder="unzip"
          opts=
          ls_opts="-l"
        else
          printf "Nothing to extract: $file ($suffix)\n"
          exploder=
          opts=
          args=
          file=
        fi
        ;;
    esac

    type $exploder >/dev/null 2>&1 \
      || ( printf "** Error: command not found: ${exploder}\n" 1>&2 && return 2 )

    if [ "$list_only" = "true" ]; then
      # just list archive contents
      do_list $file $ls_opts $args
    else
      # extract this archive AND extract certain types of nested archives
      do_extract $file $opts $args \
        && (cd "$dir" \
              && for x in ${expand_L2}
                 do
                   [ -f $x ] && ext2dir $x
                 done
                 cd - >/dev/null) \
        && de_duplicate $dir
    fi
  done
}

############################################################################
# can also just use (for a single archive):
#  file-roller -h "$FILENAME"   # extracts archive "here"
run_gui() {
  #IFS=$'\n'
  for FILENAME in $NAUTILUS_SCRIPT_SELECTED_FILE_PATHS
  do
      LOCATION=$(zenity --file-selection --directory --title="Extract $FILENAME to directory...") || exit
      type ext2dir
      ls -l "$FILENAME"
      dir="$PWD"
      ( cd $(dirname $FILENAME) && ext2dir $(basename "$FILENAME") )
      cd "$dir"
  done
}

run_extract_archives() {
  if $from_gui
  then
    run_gui "$@"
  else
    ext2dir "$@"
  fi
}

############################################################################
# main
############################################################################

list_only=false       # only list files in archive, don't extract
allow_dup_dir=false   # leave duplicate directories, e.g., foo/foo/file1.txt
rm_dup_dir_only=false # just run de-duplicate (debugging)
from_gui=false        # if gnome, allow the script to be run from a nautilus shortcut

while getopts dDghl opt
do
  case "$opt" in
  d) allow_dup_dir=true ;;
  D) rm_dup_dir_only=true ;;
  g) from_gui=true;;
  h) usage; exit 1;;
  l) list_only=true ;;
  *) printf "** unknown option\n" 1>&2 ; usage ; exit 2 ;;
  esac
done; shift $((OPTIND-1)); OPTIND=1

if [ "$rm_dup_dir_only" = "false" ]
then
  run_extract_archives "$@"
fi

# # preferable to de-duplicate after exploding everything
# if [ "$allow_dup_dir" = "false" ]
# then
#   de_duplicate "$@"
# fi
#
