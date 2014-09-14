#!/bin/sh
# Return the target of a symbolic link; e.g., given file_a.txt, such that:
#  $ ls -ld file_a.txt
#    file_a.txt -> /path/to/file_b.txt
# then, recursively resolves the target, printing the absolute path to the
# target file, returning /path/to/file_b.txt
#
# This is an alternative to 'readlink -f', if on a platform where 'readlink' isn't available.

debug=false
has_readlink=false

resolve() {
  list=$(ls -ld "$1")
  targ=`expr "$list" : '.*-> \(.*\)$'` && resolve "$targ" || echo "$1"
}

abs_path() {
  ( cd  "`dirname $1`"
    echo "$PWD/`basename $1`"; )
}

[ "$1" = "-h" ] \
    && printf "Usage: `basename $0` {file}\n  Prints canonical path to file, recusively resolving symlinks.\n" \
    && exit 2

[ "$1" = "-d" ] && shift && debug=true && type readlink >/dev/null 2>&1 && has_readlink=true
[ $# -eq 0 ] && echo "** error: expecting file"

src=$1
targ=`resolve "$src"`
targ=`abs_path "$targ"`

if $debug && $has_readlink; then
    targ_r=$(readlink -f "$src")
    [ "$targ" != "$targ_r" ] && printf "# fail: incorrect result for: $src\n# expected: $targ_r\n# was: $targ\n"
fi

echo "$targ"

