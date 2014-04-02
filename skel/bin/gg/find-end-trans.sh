#!/bin/bash
#
# scan for next transaction in a series of trail files.
#

trail=dirdat/*[09]
[ $# -gt 0 ] && trail=$@

for x in $trail
do  
   printf "==========================$(ls -l $x)\n" 
   printf "open $x \n ghdr on \n sfnt \n sfnt \n sfnt \n" |  ./logdump 
done | egrep '======|Next Trans|Len .*RBA '


