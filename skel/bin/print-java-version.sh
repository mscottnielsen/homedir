#!/bin/bash
# Print out the version of java being used -- just the version string, no
# extra characters or information. E.g., "1.7.0.67", or "1.6.0.32"
# By default, the version of java found in the PATH is printed.
#
# Usage: print-java-version.sh [-v | -t] [path_to_java]
#    -t      test mode; print out java versions found on the system
#    -v      verbose/debug output

PROG=${BASH_SOURCE[0]}

do_test() {
  for d in $(find /usr/lib/jvm/java-* /opt/jdk*/ -name bin -print -prune); do
      if [ -e "$d" ]; then
          printf "====== ${d}\n"
          printf "===========>$(  $PROG -v ${d}/java )<==\n"
          $d/java -version
          echo
      fi
  done 2>&1
}


print_java_version() {
    if $DEBUG ; then
        { echo "$JAVA_EXE"; $JAVA_EXE -version 2>&1; } | sed 's/^/DEBUG: /' 1>&2
    fi

    if [ -e $JAVA_EXE ] ; then
        $JAVA_EXE -version  2>&1 | grep -i version | head -1 \
             | sed 's/^[^0-9][^0-9]*//; s/[^0-9]/./g; s/\.$//'
    fi

}

[ "$1" = "-v" ] && shift && DEBUG=true || DEBUG=false
[ "$1" = "-t" ] && shift && DO_TEST=true || DO_TEST=false
[ $# -gt 0 ] && JAVA_EXE=$1 || JAVA_EXE=$(type -p java)

$DO_TEST && do_test || print_java_version

