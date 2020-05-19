#!/bin/bash

usage() {
  cat<<EOF
  Usage: $PROG [-h|-n] {url}
    -h   print help usage info and exit
    -n   dry-run, only print what would be run, then exit

  Run 'git clone' on a URL, but do the clone in a subdirectory,
  named after the project owner (the first part of the URL).

  Example:
     The following will create a git clone in: sampleuser/some-project/...
     $PROG  git@github.com:sampleuser/some-project.git
     $PROG  https://github.com/sampleuser/some-project.git
EOF
}

RUN=
PROG=${BASH_SOURCE[0]##*/}

do_clone() {
  local url=$1   # eg: git@github.com:foobar/app.git or https://github.com/foobar/app.git
  local rest=$2          # eg: foobar/app.git
  local dir=${rest%/*}   # eg: foobar
  local proj0=${rest#*/} # eg: app.git
  local proj=${proj0%.*} # eg: app
  printf "\n# == dir:  ${dir}\n# == proj: ${proj}\n# == url:  ${url}\n"
  ( $RUN mkdir -p "$dir" && $RUN cd "$dir" && $RUN git clone "$url" && $RUN cd - )
}

[[ $1 = "-n" ]] && RUN=echo && shift
[[ $1 = "-h" || $# = 0 ]] && { usage; exit 2; }

for arg; do
  if echo "$arg" | egrep -q 'git@github'; then
    do_clone "$arg" "${arg#*:}"
  elif echo "$arg" | egrep -q 'http.*://'; then
    do_clone "$arg" "${arg#*\.com\/}"
  else
    printf "\n** error: unrecognized URL format: ${arg}\n\n" 1>&2
    usage
    exit 2
  fi
done

