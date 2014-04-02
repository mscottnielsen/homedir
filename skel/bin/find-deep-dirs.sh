#!/bin/bash

prog=${BASH_SOURCE[0]##*/}
usage() { cat<<EOF
  Usage:  $prog {filename_regex_pattern}
  Find longest paths, using the locate database,
  assuming to search below \$PWD
  Example: $prog '/foo.*2013.*log$'
EOF
}

#find . -type d -exec bash -c 'echo $(tr -cd / <<< "$1"|wc -c):$1' -- {} \;  | sort -n | tail -n 1 # | awk -F: '{print $1, $2}'

pattern=$1
locate -r "^$PWD/.*/$pattern" \
   | while read f; do printf "$(tr -cd / <<< "$f" | wc -c):$f\n"; done \
   | sort -nr -t: -k1 \
   | head -5



