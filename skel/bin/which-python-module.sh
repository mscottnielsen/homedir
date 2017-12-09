#!/bin/bash

list_pythons() {
    which -a $( echo python python2 python3 python{2..3}{.,}{1..9} ) 2>/dev/null
}

for m
do
  echo "======= $m ========="
  for py in $( list_pythons )
  do
    printf "${py}:\t"
    $py -c "import sys,${m}; print(sys.modules['${m}'])" 2>/dev/null || echo
  done
done

