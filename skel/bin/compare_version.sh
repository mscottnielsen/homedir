#!/bin/bash

strip_num() { # remove everything except numbers and "."
  sed 's/[^0-9\.]//'
}

trim_s() {  # sanitize input data (sed version)
  echo "$1" \
     | sed 's/^ *0\.*//; s/\.0 *$//; s/\.\.*/\./g; s/\.$//; s/^\.//' \
     | strip_num
}

# compare two numbers, e.g., num_compare 23.5.1 23.5.2; ret=$?
#    if [ $ret -eq 0 ] ... equal
#    elif [ $ret -eq 1 ] ...greater-than;
#    else  ...less-than
num_compare () {
  #  x == y   => return 0
  #  x > y    => return 1
  #  x < y    => return 2  (-1)
  # : "## compare: a=$1 / b=$2"
  [ $1 -eq $2 ] && return 0
  [ $1 -gt $2 ] && return 1
  [ $1 -lt $2 ] && return 2
}

version_compare () { # compare version strings: x, y
   local X=$(trim_s $1)
   local Y=$(trim_s $2)
   local X_dots=${X//[^.]/} # just get "." (sans numbers): 1.2.3 => ...
   local Y_dots=${Y//[^.]/}

   if [ ${#X_dots} -eq 0 -a ${#Y_dots} -eq 0 ]; then
     num_compare $X $Y              # : "# compare numbers: X=$X / Y=$Y"
     return
   elif [ ${#Y_dots} -eq 0 ]; then
     return 1                       # : "# Y shorter: $Y / $Y_dots"
   elif [ ${#X_dots} -eq 0 ]; then
     return 2                       # : "# X shorter: $X / $X_dots"
   else                             # continue comparing: $X / $Y
     # ${X%%.*} => head: 1.2.3 => 1  (if head_X=head_Y, compare tails)
     # ${Y#*\.} => tail: 1.2.3 => 2.3
     num_compare ${X%%.*} ${Y%%.*} && version_compare ${X#*\.} ${Y#*\.}
     return $?
   fi
}

version_compare $@

