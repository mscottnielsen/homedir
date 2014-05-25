#!/bin/bash
# Ask a question, provide a yes/no answer, and return true or false.

do_ask() {
    do_usage() { cat<<EOF
  Usage:  do_ask {question} && echo 'success' || echo 'failure'

  Options:
    -q  - quit is an option, which returns status=2 (doesn't actually 'exit')
    -Q  - quit is an option, process exists

  Return: 0 (true=yes), 1 (false=no), 2 (quit)

  Example:
    $ do_ask -q "are you sure?" && echo "***ok $?***" || echo "===no $?==="
      are you sure? [y|n|q] (default=y) y
      ***ok 0***
EOF
  }

  local yn='y' exit_on_quit=false allow_quit=false opts='[y|n]'

  [ "$1" = "-q" ] && shift && allow_quit=true
  [ "$1" = "-Q" ] && shift && allow_quit=true && exit_on_quit=true
  [ "$1" = "-h" ] && { do_usage; return 1; }

  $allow_quit && opts='[y|n|q]'

  read -N 1 -s -p "$@ $opts (default=y) " yn

  [ "$yn" = "y" -o -z "$yn" ] \
      && printf " [answer=$yn => yes]\n" 1>&2 \
      && return 0

  $allow_quit && [ "$yn" = "q" ] \
      && printf " [answer=$yn => QUIT]\n" 1>&2 \
      && { $exit_on_quit && exit 2 || return 2; }

  printf "\n" 1>&2

  return 1
}

# allow sourcing this script, to use do_ask() as a function
[ $# -gt 0 ] && do_ask "$@"

