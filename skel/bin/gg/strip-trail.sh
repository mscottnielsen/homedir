#!/bin/bash
#
# Strip dates, sequence number/RBA, etc in text files that are otherwise equal.
# For example, when comparing GoldenGate logdump output, GG Java adapater or
# file-writer text/XML output, report files, logs, etc.
#
# Used to compare GG column data & record counts, discarding differences in
# introduced just by pumping data from one location to another.
##############################################################################


##############################################################################
strip_position() {
  # convert 20-char (seqno+rba) to zeros/nines/blanks. Options:
  #  -e   erase number; eg: x00000012340000005678x => xx
  #  -z   fill w/ 0's;  eg: x00000012340000005678x => x00000000000000000000x
  #  -9   fill w/ 9's;  eg: x00000012340000005678x => x99999999999999999999x

  local ten_zeros=00000000000000000000
  local ten_nines=99999999999999999999
  local fill=$ten_nines

  [ "$1" = "-e" ] && fill="" && shift
  [ "$1" = "-z" ] && fill=$ten_zeros && shift
  [ "$1" = "-9" ] && fill=$ten_nines && shift

  # search for 20 consecutive digits anywhere in the pattern
  #$SED "s/\([^0-9]*\)\([0-9]\{20\}\)\([^0-9]*\)/\1${fill}\3/g"

  exact() { $SED "s/^[0-9]\{20\}$/${fill}/g" ; }
  front() { $SED "s/^[0-9]\{20\}\([^0-9]\)/${fill}\1/g" ; }
  end()   { $SED "s/\([^0-9]\)[0-9]\{20\}$/\1${fill}/g" ; }
  middle() { $SED "s/\([^0-9]\)[0-9]\{20\}\([^0-9]\)/\1${fill}\2/g" ; }
  double() { $SED "s/\([^0-9]\)[0-9]\{20\}\([^0-9]\)[0-9]\{20\}\([^0-9]\)/\1${fill}\2${fill}\3/g"  ; }

  exact |  front | end | middle  | middle | double
}

##############################################################################
# gnu sed does have a case-insensitive match "/I", but is not portable
sed2() {
  local opt=g arg=$1
  if [ ${#arg} -eq 2 -a "$1" = "-i" ]; then
    arg=$2
    $has_gnu_sed && opt="Ig"
    $SED "s/\(${arg}[=: ]*\)\{1,2\}\([0-9]*\)/\1xxxxxx/$opt"
  fi
}

##############################################################################
strip_seqno() {
  if $has_gnu_sed ; then
    sed2 -i seqno
  else
    sed2 seqno | sed2 SeqNo
  fi
}

##############################################################################
strip_rba() {
  if $has_gnu_sed ; then
    sed2 -i rba
  else
    sed2 rba | sed2 RBA
  fi
}

##############################################################################
strip_logdump_prompt() {
  grep -v '^Logdump .* >$'
}

##############################################################################
# testing
do_test() {
  # timestamp
  ts() { date  '+%F %R'; }

  # function(s) to test
  test_ftn() {
    #strip_position "$@"
    strip_position "$@" | strip_seqno | strip_rba
  }

  run_test() {
    # usage: run_test [options] string1 [string2]
    #   given string1, the ftn shouldn't change the string.
    #   given string1 string2, the first string should produce the second
    local opt=""
    [ $# -gt 0 -a "${1:0:1}" = "-" ] && opt=$1 && shift

    local input=$1 expected="[$1]"
    [ $# -gt 1 ] && expected="[$2]"

    local result=$(printf "${input}\n" | test_ftn $opt | $SED 's/.*/[&]/')
    if [ "${expected}" != "$result" ] ; then
      printf " *** FAIL: opt=\"$opt\" *** input: \"$1\"\n *** expected: \"$expected\"\n *** actual:   \"$result\"\n"
      return 1
    else
      printf "OK: input=\"[$1]\", expected=\"$expected\"\n"
      return 0
    fi
  }

  # all tests use seqno=7,rba=7654: 0000000007+0000007654
  local test_num=0 pass=0 fail=0
  local opt input_var expect_var desc_var

  local test_1_desc="test:  ^pat$"
  local test_1_input='00000000070000007654'
  local test_1_expect_e=''
  local test_1_expect_9='99999999999999999999'
  local test_1_expect_z='00000000000000000000'

  local test_2_desc="test:  ^...pat$"
  local test_2_input='test a00000000070000007654b00000000070000007654'
  local test_2_expect_e='test ab'
  local test_2_expect_9='test a99999999999999999999b99999999999999999999'
  local test_2_expect_z='test a00000000000000000000b00000000000000000000'

  local test_3_desc="test:   ^pat...$"
  local test_3_input='00000000070000007654 00000000070000007654 test'
  local test_3_expect_e='  test'
  local test_3_expect_9='99999999999999999999 99999999999999999999 test'
  local test_3_expect_z='00000000000000000000 00000000000000000000 test'

  local test_4_desc="test:  ^...pat...$"
  local test_4_input='a00000000070000007654b00000000070000007654c'
  local test_4_expect_e='abc'
  local test_4_expect_9='a99999999999999999999b99999999999999999999c'
  local test_4_expect_z='a00000000000000000000b00000000000000000000c'

  local test_5_desc="test:  ^...pat...$"
  local test_5_input=' 00000000070000007654 00000000070000007654 '
  local test_5_expect_e='   '
  local test_5_expect_9=' 99999999999999999999 99999999999999999999 '
  local test_5_expect_z=' 00000000000000000000 00000000000000000000 '

  local test_6_desc="test:  ^...patpat...$"
  local test_6_input='00000000070000007654000000000700000076548' # extra trailing '8'
  local test_6_expect_e=$test_6_input
  local test_6_expect_9=$test_6_input
  local test_6_expect_z=$test_6_input
  #local test_6_expect_e=8                                            ## wrong
  #local test_6_expect_9='99999999999999999999999999999999999999998'  ## wrong
  #local test_6_expect_z='00000000000000000000000000000000000000008'  ## wrong

  local test_7_desc="test:  ^...patpat...$"
  local test_7_input='80000000007000000765400000000070000007654'   # extra leading '8'
  local test_7_expect_e=$test_7_input
  local test_7_expect_9=$test_7_input
  local test_7_expect_z=$test_7_input
  #local test_7_expect_e='4'
  #local test_7_expect_9='99999999999999999999999999999999999999994'
  #local test_7_expect_z='00000000000000000000000000000000000000004'

  local test_8_desc="test:  seqno, rba"
  local test_8_input='seqno=0000000007 rba=00000076540 SeqNo: 000000007 RBA: 0000007654'
  local test_8_expect_e='seqno=xxxxxx rba=xxxxxx SeqNo: xxxxxx RBA: xxxxxx'
  local test_8_expect_9=$test_8_expect_e
  local test_8_expect_z=$test_8_expect_e

  local test_9_desc="test:  ^...pat...$"
  local test_9_input='a00000000070000007654b00000000070000007654c seqno: 1234 a00000000070000007654b00000000070000007654c rba=5678'
  local test_9_expect_e='abc seqno: xxxxxx abc rba=xxxxxx'
  local test_9_expect_9='a99999999999999999999b99999999999999999999c seqno: xxxxxx a99999999999999999999b99999999999999999999c rba=xxxxxx'
  local test_9_expect_z='a00000000000000000000b00000000000000000000c seqno: xxxxxx a00000000000000000000b00000000000000000000c rba=xxxxxx'

  # which testcases to run (start => end)
  local start=1 max=9

  printf "\n##===BEGIN=[$(ts)] run tests=$max\n"
  for x in $(seq $start $max) ; do
    for y in e 9 z ; do
      input_var=test_${x}_input
      expect_var=test_${x}_expect_${y}
      desc_var=test_${x}_desc
      opt="-${y}"
      printf "## test #$(( test_num++ )) ($pass/$fail): test_$x ($opt) ${!desc_var}\n"
      if run_test $opt "${!input_var}" "${!expect_var}" ; then
        (( pass++ ))
      else
        (( fail++ ))
      fi
    done
  done
  printf "##===END=[$(ts)]  pass: $pass/$test_num ($(echo $pass/$test_num \* 100 |bc -l|cut -c1-5)%%) (fail=$fail)\n"
}

##############################################################################
# main
do_main() {
  local opt=""
  [ $# -gt 0 -a "${1:0:1}" = "-" ] && opt=$1 && shift

  if [ $# -eq 0 ] ; then
    strip_position $opt | strip_seqno | strip_rba
  else
    for x ; do
      cat $x | strip_position $opt | strip_seqno | strip_rba
    done
  fi
}

##############################################################################
: ${has_gnu_sed:=false}
: ${SED:="$(type gsed > /dev/null 2>&1 && echo gsed || echo sed)"}
$SED --version 2>&1 | grep -q GNU && has_gnu_sed=true

prog_name=${BASH_SOURCE[0]##*/}           # this script basename (=basename $0)
opt=

if [ "${prog_name%%-*}" = "test" ]; then  # if script named test-*.sh, run tests
  do_test "$@"
else
  [ $# -gt 0 -a "${1:0:1}" = "-" ] && opt=$1 && shift
  do_main $opt "$@"
fi

