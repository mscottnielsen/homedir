#!/bin/bash
#
# Tests for check-oggadp-libs.sh
#

TEST_PROG_PATH=${BASH_SOURCE[0]}
TEST_PROG_NAME=${TEST_PROG_PATH##*/}
TEST_PROG_DIR="$(cd "$(dirname "${TEST_PROG_PATH:-$PWD}")" 2>/dev/null 1>&2 && pwd)"

PROG_DIR="$(cd "${TEST_PROG_DIR}"/.. 2>/dev/null 1>&2 && pwd)"
PROG_NAME=${TEST_PROG_NAME/-test.sh/.sh}
PROG_PATH="$PROG_DIR"/"$PROG_NAME"

. "$PROG_PATH" 2>/dev/null


test_verify() {
  local opt OPTIND OPTARG
  local ret=0 desc="" actual0="" result="" quiet=0 verbose=0 esc=0

  while getopts d:eqv opt; do
    case "$opt" in
      d) desc=${OPTARG};;
      e) esc=1;;
      q) quiet=1;;
      v) verbose=1;;
      *) printf "** Warning: ${FUNCNAME}: unknown option ($*)\n" 1>&2;;
    esac
  done; shift $((OPTIND-1)); OPTIND=1

  printf "\n========= ${FUNCNAME[1]}:===== $desc\n"
  local cmd="$1" expect0="$2"
  [ "$cmd" = "" ] && printf "** Error: missing test command\n" && return 2
  [ $esc -eq 0 ] \
      && actual0="$( $cmd )" \
      || actual0="$( $(printf "$cmd") )"

  [ "${expect0}" = "${actual0}" ] && result="PASS" || result="FAIL"

  [ $quiet -eq 0 ] \
    && printf "===$result: [$cmd]\n" \
    || printf "===$result\n"

  if [ "$result" = "FAIL" ]; then
     printf "=******************=\n"
     printf "expect:  [${expect0}]\n"
     printf "actual:  [${actual0}]\n"
     printf "=******************=\n\n"
     ret=1
  else
     [ $quiet -eq 0 ] && printf "=result: [${expect0}]\n"
     ret=0
  fi
  return $ret
}

# regexp_from_list  returns space at begin and anchor ("$") at end.
# test options: 
#   -e   => no anchors: given "one two" return "one|two"
#   -s   => no space added at start
#   -w   => match whole words (implies "-s"): return "^word$", not " word$"
test_regexp_from_list () {
  echo "==============${FUNCNAME}============================="
  test_verify -d "test1" \
     'regexp_from_list -w  one two three four foo{.bat,.bar}' \
     '^one$|^two$|^three$|^four$|^foo.bat$|^foo.bar$'

  test_verify  -d "test2" \
     'regexp_from_list     one two three four foo{.bat,.bar}' \
     ' one$| two$| three$| four$| foo.bat$| foo.bar$'

  test_verify  -d "test3" \
     'regexp_from_list -s  one two three four foo{.bat,.bar}' \
     'one$|two$|three$|four$|foo.bat$|foo.bar$'

  test_verify -e -d "test4" \
     'regexp_from_list -s one \n\ntwo \n three four \t foo{.bat,.bar,} \n' \
     'one$|two$|three$|four$|foo.bat$|foo.bar$|foo$'
}

test_regexp_from_list_examples () {
  # Examples:
  test_verify  -d "test5" \
    'regexp_from_list -w one two three four foo.bat foo.bar' \
    '^one$|^two$|^three$|^four$|^foo.bat$|^foo.bar$'

  test_verify  -d "test6" \
    'regexp_from_list    one two three four foo.bat foo.bar' \
    ' one$| two$| three$| four$| foo.bat$| foo.bar$'

  test_verify  -d "test7" \
    'regexp_from_list -s one two three four foo{.bat,.bar}' \
    'one$|two$|three$|four$|foo.bat$|foo.bar$'

  # The following would return the same string:
  local tmp1="one two three four foo.bat foo.bar"
  local tmp2="one   two\n three\n\n four\n foo.bat  foo.bar"
  local tmp3="{one,two} three four foo{.bat,.bar}"
  local exp=" one$| two$| three$| four$| foo.bat$| foo.bar$"

  test_verify    -d "test8"  "regexp_from_list $tmp1" "$exp"
  test_verify -e -d "test9"  "regexp_from_list $tmp2" "$exp"
  test_verify    -d "test10" "regexp_from_list $tmp3" "$exp"
}

do_test() {
  test_regexp_from_list 
  test_regexp_from_list_examples
}


do_test


