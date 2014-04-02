#!/bin/bash

##############################################################################
# print version info for GoldenGate executables/libraries/jars (any platform);
# mostly for oggadp, but also shows oggcore version info
##############################################################################


##############################################################################
# search for goldengate installations (finding "ggsci" is good enough)
#
list_gg_homes() {
    local gg
    for gg in $( find "$@" -depth -name ggsci -print -prune ) ; do
        echo $(dirname $gg)
    done
}


##############################################################################
# Given an executable or library, use "strings" looking for version strings
# in the binary. For a jar, look for version info in the manifest.
#
get_prog_version() {
    local file

    do_format() {
        # sort in reverse (used to omit duplicate strings), remove special chars
        strings | sort -ru
    }

    for file ; do
        case "$file" in
            *.jar )
                unzip -p "${file}" META-INF/MANIFEST.MF | egrep -- 'Implementation-Version|Specification-Version' | do_format
                ;;
            */ggsci )
                strings "$file" 2>/dev/null | egrep '^Version' | egrep -v 'Version %s, Release %s|of checkpoint rec|Version [A-Z]$' | sed 's/^Version[ _]*//; s/\t/_/g; s/[\/(), ]/_/g; s/__*/_/g; s/^_*//; s/_*$//' | do_format
                ;;
            */flatfile* | */lib*java* )
                strings "$file" 2>/dev/null | egrep '^[1-9][0-9]*\.[0-9]|API:|^Version *[0-9]' | egrep -v ' -I\.\.|^[4-9]\.0C$' | do_format
                ;;
            * )
                echo "ERROR: unknown file : $file"
                ;;
        esac
    done
}

##############################################################################
# get just the number part of a filename; e.g., foo-1.2.3.4.jar => 1.2.3.4
#
get_version_from_filename() {
    echo "$@" | sed 's/[^-\._0-9]//g' | sed 's/^[^0-9]//g; s/[^0-9]$//g' | sed 's/^ *\. *$//'
}


##############################################################################
# print version info for the given file (jar, lib, exe)
#
print_version_info() {
    local ff line guideprev prog=$1
     ff=$(basename $prog)
     printf "#  $ff => \t"

     guess=$(get_version_from_filename "$ff")
     prev=""  # don't print redundant substrings
     while read line ; do
         [ "${prev}" = "" ] && { prev=$line ; printf "  $line"; continue; }
         [[ ${prev} == *${line}* ]] || printf "  /  $line"
         prev=$line
     done < <( get_prog_version "$prog" )
     [ "$prev" = "" ] && printf "${guess:-"(no version info)"}"
     printf "\n"
}


##############################################################################
# list of all exe's & libs & jars to check for version info. Force ggsci
# to be sorted first, followed by other libs/exe/jars alphabetically.
#
find_progs() {
    local f
    for f in $( find $@ -maxdepth 2 \( -name "ggsci" -o -name "lib*java*.so" -o -name "*flatfile*.so" -o -name "ggjava" \) -print -prune | sed 's/ggsci$/01-&/' | sort -u ); do
        case "$f" in
             */ggjava )
                 find "$f" -maxdepth 4 \( -name "ggutil*.jar" -o -name "ggjava.jar" \) -print -prune | sort -u
                 ;;
             *ggsci )
                 echo "$f" | sed 's/01-ggsci$/ggsci/'
                 ;;
             * )
                 echo "$f"
                 ;;
         esac
    done
}


##############################################################################
# print version info for all the given files (jar, lib, exe), and
# log to output file (with PID in filename)
#
list_all_exe_versions() {
    local prog ff gg guess line out=versions.$$.txt
    [ -f "$out" ] && { echo "** error: output file exists: $out" ; return 2; }

    for gg in $(list_gg_homes "$@" | sort -u) ; do
        printf "\n# ====== $gg ==\n"
        for prog in $( find_progs $gg ) ; do
            print_version_info "$prog"
        done
    done | tee $out
}


##############################################################################
#  search given directories for all GG installations, and see if version
#  info for GG & adpaters can be printed (logged to output file)
##############################################################################

[ $# -gt 0 ] \
    && list_all_exe_versions $@ \
    || list_all_exe_versions */

