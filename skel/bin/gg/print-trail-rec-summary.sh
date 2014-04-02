#!/bin/bash

# Given GoldenGate trail files, print each record (operation) on a single line.
# This provides both a summary of the activity in the trail (number and types of
# operations in a trail), but also allows easy post-processing by other GNU/un*x
# utilities (e.g., grep/sed/awk).
#
# This script calls 'print-trail.sh' (expected to be in the same directory as
# this script) to dump a trail to stdout using logdump. This script then runs
# a series of filters on logdump's output to print on a single line: operation
# type (insert/update/delete), tx-indicator (begin/middle/end/whole), trail
# sequence#/RBA, audit RBA, etc. Then everything is rearranged/reformatted
# on a single line.

usage() { cat <<EOF
 Usage: $PROGNAME [-A -h -i -n][-N {num}][-p {pos}][-f {pattern}][-c|-C {pattern}] {trail...}

 Use GoldenGate logdump on trail(s), reformatting, summarizing and filtering
 the output to print each operation on a single line.


 Arguments:
   {trail} - either a path to a trail, or a two character prefix to process
             all files in the trail series (dirdat/ab000023 or dirdat/ab)

 General Options:
    -a         - include audit RBA and position (from the data source)
    -f {pattern} - filter on pattern (just grep's; does not use logdump filters)
    -h         - print usage and exit
    -i         - indent transactions
    -n         - print line numbers
    -N {num}   - print max 'num' records (note: trail headers are records, too)
    -p {pos}   - start at trail position {pos}
    -R         - exclude trail RBA (included by default)
    -T         - do NOT print trail pathnames in output (included by default)

 Advanced options:
    -A         - for input already in ascii logdump output format
    -c         - colorize output on a "RestartAbend"
    -C {pattern} - colorize output on the given pattern
    -B {string}  - mark consecutive 'before' records in the trail, appending
                 the given string to the record, e.g., "-B HERE":
                 (x01) A (x41)...FieldComp...RBA 3935   SCH.TABLE === HERE

 This script requires '${PRINT_TRAIL_SH##*/}' in order to run logdump to
 convert binary trails into text output (see also: -A). The script is:
   (1) found in the same directory as this script, currently: $PROGDIR
   (2) or, set using an env variable, default: PRINT_TRAIL_SH=$PRINT_TRAIL_SH
  The logdump utility is found:
   (1) in the current directory
   (2) or, one directory level higher (if invoked from inside "dirdat")
   (3) or, set LOGDUMP=path/to/logdump

 Pre-generated logdump-formatted ascii output can be processed ("ghdr on" must
 be enabled); either from stdin:
    $ printf 'open dirdat/ab000000\n ghdr on\n next\n next\n' | ./logdump | $PROGNAME -A
 or, from a file:
    $ printf 'open dirdat/ab000000\n ghdr on\n next\n next\n' | ./logdump > foo.out
    $ $PROGNAME -A foo.out

 See also: print-trail.sh

EOF
  return 0
}

#############################################################################
usage_exit() {
  usage
  exit $1
}

##############################################################################
filter_logdump() {
  eval "$filters"
}

##############################################################################
perf() {
 /usr/bin/time -a -f "%E, %U" -o /tmp/$progname.time.${FUNCNAME[1]}.txt
}


##############################################################################
# Record header:
# ___________________________________________________________________
# Hdr-Ind    :     E  (x45)     Partition  :     .  (x04)
# UndoFlag   :     .  (x00)     BeforeAfter:     A  (x41)
# RecLength  :    98  (x0062)   IO Time    : 2010/04/27 16:01:07.000.000
# IOType     :     5  (x05)     OrigNode   :   255  (xff)
# TransInd   :     .  (x01)     FormatType :     R  (x52)
# SyskeyLen  :     0  (x00)     Incomplete :     .  (x00)
# AuditRBA   :      38773       AuditPos   : 9134412
# Continued  :     N  (x00)     RecCount   :     1  (x01)
#
# 2010/04/27 16:01:07.000.000 Insert               Len    98 RBA 338
# Name: MNIELSEN.TCUSTORD
# ===========================================================================
# From this record, collect and reformat the following:
#   ______... => the record boundary
#   "^trail" => trail name, from print-trail script
#   TransInd => begin/middle/end transaction indicator
#   AuditRBA => source RBA/Position
#   UndoFlag => BeforeAfter flag
#   2013/03/30 (timestamp, pattern="^2.../../") => op type, length, RBA
#   Name  => table name
##############################################################################

# fix logdump output, insert newline, to put "__*" on a line, when
# output is: Logdump 123456 >____
do_fix0() { #perf \
   # sed 's/^Logdump *[0-9]* *> *n*__/Logdump>\n__/g' # sed '\n' not supported hp-ux
   sed 's/^Logdump [0-9]* > *n*__/__/'
}

# first, just get rows of interest
do_summary1() { #perf \
  $should_display_trail \
    && $AWK '/^trail|^___|^Trans|^Audit|^Undo|^Name:|^20../ { print $0 }' \
    || $AWK        '/^___|^Trans|^Audit|^Undo|^Name:|^20../ { print $0 }'
  return 0
}

##############################################################################
# normalize & remove unwanted output, eg: "BeforeAfter: B (x42)" => "B (x42)"
# and break up longer lines, eg, convert one line:
#   2012/03/30 13:19:00.992.510 Delete  Len 23  RBA 123
# into multiple lines: (nb: "\n" not supported on all unix (non-gnu) sed, e.g. hp-ux)
#    =2012/03/30\n         #1
#    =13:19:00.992.510\n   #2
#    =Delete\n             #3
#    =Len 23\n             #4
#    =RBA 123\n            #5
do_strip2() { #perf \
  sed 's/^_____* */__/;
       s/         /    /g;
       s/^Undo.*After:  *\([^ ]*\)  *\((.*)\) *$/=\1\2/;
       s/^TransInd[ .:]* *\((x[0-9]*)\).*/=\1/;
       s/^Name:  *\([^ ]*\) *$/=\1/;
       s/^\(2...\/..\/..\) \([0-9][0-9:.]*\)  *\([A-Za-z]*\)  *Len  *\([0-9][0-9]*\)  *\(RBA *[0-9][0-9]* *\)/=\1\
=\2\
=\3\
=Len \4\
=\5/;
       s/AuditRBA *: *\([0-9][0-9]*\) */=AuditRBA:\1/;
       s/AuditPos *: *\([0-9][0-9]*\) */\
=Pos:\1/'
  return 0
}

##############################################################################
# put everything back into a single line; fields prefixed by "="
do_paste3() { #perf \
  #sed -e ':a' -e '$!N;s/\n=/\*/;ta' -e 'P;D'
  sed -e ':a' -e '$!N;s/\
=/\*/;ta' -e 'P;D'

  return 0
}

##############################################################################
# reorder the fields
#   1  _______ (line)
#   2: =B(x42)           #2 (second field)
#   3: =(x01)  (tx-ind)  #1 (first field)
#   4: =AuditRBA:1772    #8
#   5: =Pos:69431108     #9
#   6: =2013/03/30       #3
#   7: =13:19:00.992.510 #4
#   8: =Delete           #5
#   9: =Len 12           #6
#  10: =RBA 692          #7
#  11: =LSC.T4           #10
#
# optionally include/exclude trail seqno/rba, audit pos/rba

# include trail seqno/rba (no audit rba/pos)
do_reorder4_rba() {
  $AWK -F\* '/^trail/ { print $0 }
    /^__/ { printf "%s \t %s \t %s \t %s \t %s \t %s \t %s \t %s\n", $3, $2, $6, $7, $8, $9, $10, $11 }'
}

# include audit rba/pos (no trail seqno/rba)
do_reorder4_audit() {
  $AWK -F\* '/^trail/ { print $0 }
    /^__/ { printf "%s \t %s \t %s \t %s \t %s \t %s \t %s,%s\t %s\n", $3, $2, $6, $7, $8, $9, $4, $5, $11 }'
}

# include seqno/rba & audit rba/pos
do_reorder4_include_both() {
  $AWK -F\* '/^trail/ { print $0 }
    /^__/ { printf "%s \t %s \t %s \t %s \t %s \t %s \t %s \t %s,%s\t %s\n", $3, $2, $6, $7, $8, $9, $10, $4, $5, $11 }'
}

# no trail seqno/rba, no audit rba/pos
do_reorder4_skip_both() {
  $AWK -F\* '/^trail/ { print $0 }
    /^__/ { printf "%s \t %s \t %s \t %s \t %s \t %s \t %s\n", $3, $2, $6, $7, $8, $9, $11 }'
}

do_reorder4() { #perf \
  $do_reorder4_ftn
  return 0
}

##############################################################################
# simple grep for records to include in output
do_grep5() { #perf \
  egrep $grep_opts5 "$filter|^trail"
  return 0
}

##############################################################################
# mark records where there were two consecutive before records (to find a
# specific problem while debugging a bad trail)
do_find_consec_befores6() { #perf \
  $AWK -v M="$MARK_BEFORE" '
     { printf "%s", $0 }
     (($3 ~ /(x42)/) && (prev ~ $3))  { printf   " === %s", M }
     { printf "\n"; prev=$3; }'
  #sed "/x42/{ N; /x42.*x42/s/^.*x42.*/& === ${MARK_BEFORE}\n/ }"
  return 0
}

##############################################################################
# indent begin/middle/end transactions (whole txn's are not indented)
do_indent7() { #perf \
  sed 's/.x0[012]./  &/; s/.x01./  &/'
  return 0
}

##############################################################################
# insert line numbers into the output for records within a trail
do_number () { #perf \
  awk 'BEGIN {n=1;} /^ *\(/ { print n ":\t", $0; n++; } /^trail/ { print $0 }'
  return 0
}

##############################################################################
# uses grep to colorize, etc (but does not necessarily filter)
do_reformat () { #perf \
  egrep $grep_opts "$pattern"
  return 0
}

##############################################################################
# run logdump, generating text output from (binary) trail data
process_binary_trails() {
  $PRINT_TRAIL_SH "$@" | filter_logdump
}

##############################################################################
# already ascii output from logdump
process_ascii_dump() {
  local txt_file
  if [ $# -eq 0 ]; then
    $verbose && printf "# reading from stdin..." 1>&2
    filter_logdump
  else
    #printf "# reading files: $@"
    for txt_file ; do
      [ ! -f "$txt_file" ] && echo "** error: file not found: $txt_file" 1>&2 && continue
      $should_display_trail && printf "trail $txt_file\n"
      cat $txt_file  | filter_logdump
    done
  fi
}

##############################################################################
# main
##############################################################################
PROG=${BASH_SOURCE[0]}
PROGNAME=${BASH_SOURCE[0]##*/}
PROGDIR=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)
: ${PRINT_TRAIL_SH:=$PROGDIR/print-trail.sh}


# use GNU awk and GNU sed, if possible (esp. Solaris)
type gawk > /dev/null 2>&1 && AWK=gawk || AWK=awk
type gsed > /dev/null 2>&1 && SED=gsed || SED=sed

# pass through to $PRINT_TRAIL_SH
print_trail_opts=

is_binary_input=true
should_indent=false
should_display_trail=true
should_mark_befores=false
should_number=false
include_trail_rba=true
include_audit_rba=false
verbose=false

# to colorize
pattern="^"
grep_opts=
should_reformat=false

# function to call (include/exclude audit/trail seqno/rba)
do_reorder4_ftn=do_reorder4_rba

# to grep/filter
filter="."
should_filter=false
OPTIND=1

while getopts aAB:cC:f:hiN:np:RtTv opt; do
  case "$opt" in
    a) # include trail audit RBA (excluded by default)
       include_audit_rba=true
       ;;
    A) is_binary_input=false
       ;;
    B) should_mark_befores=true
       MARK_BEFORE="${OPTARG}"
       ;;
    c) # colorize output on a "RestartAbend"
       should_reformat=true
       grep_opts="$grep_opts --color=always"
       pattern="^|^.*Restart.*"
       ;;
    C) # colorize output on a given pattern
       should_reformat=true
       grep_opts="$grep_opts --color=always"
       pattern="^|${OPTARG}"
       ;;
    f) filter=${OPTARG}
       should_filter=true
       ;;
    h) usage_exit 1
       ;;
    i) # indent transactions
       should_indent=true
       ;;
    n) # print line numbers
       should_number=true
       ;;
    N) # max num records
       print_trail_opts="$print_trail_opts -N ${OPTARG}"
       ;;
    p) # start at given position
       print_trail_opts="$print_trail_opts -p ${OPTARG}"
       ;;
    R) # exclude trail RBA
       include_trail_rba=false
       ;;
    t) should_display_trail=true
       ;;
    T) should_display_trail=false
       ;;
    v) verbose=true
       ;;
    *) usage_exit 2
       ;;
  esac
done; shift $((OPTIND-1)); OPTIND=1

# if no args, assume pipeline, receiving logdump output, e.g.,
#  $ print-trail.sh dirdat/aa | print-trail-rec-summary.sh | ...
[ $# -eq 0 ] && is_binary_input=false

# the first four filters create a readable, single-line logdump
# trail summary that can be filtered, indented, colorized, etc
#filters=' do_fix0 '
#filters=' do_fix0 | do_summary1 '
#filters=' do_fix0 | do_summary1 | do_strip2 '
#filters=' do_fix0 | do_summary1 | do_strip2 | do_paste3 '
filters=' do_fix0 | do_summary1 | do_strip2 | do_paste3 | do_reorder4 '

$should_filter       && filters=" $filters | do_grep5 "
$should_number       && filters=" $filters | do_number "
$should_mark_befores && filters=" $filters | do_find_consec_befores6 "
$should_indent       && filters=" $filters | do_indent7 "
$should_reformat     && filters=" $filters | do_reformat "

# set function for rba/seqno, audit-rba/pos
if     $include_audit_rba &&   $include_trail_rba ; then do_reorder4_ftn=do_reorder4_include_both
elif   $include_audit_rba && ! $include_trail_rba ; then do_reorder4_ftn=do_reorder4_audit
elif ! $include_audit_rba &&   $include_trail_rba ; then do_reorder4_ftn=do_reorder4_rba
elif ! $include_audit_rba && ! $include_trail_rba ; then do_reorder4_ftn=do_reorder4_skip_both
else
  printf "** warning: unable to determine if RBA should be included in output\n" 1>&2
fi

if $is_binary_input ; then
  process_binary_trails $print_trail_opts "$@"
else
  process_ascii_dump "$@"
fi

