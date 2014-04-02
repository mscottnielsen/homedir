#!/bin/bash
# Ask a question, provide a yes/no answer, and return true or false.
# The question to ask is arg $1
#
# return: 0 (true=yes), 1 (false=no), 2 (quit) (doesn't actually 'exit')
#
# Usage:  do_ask {question} && echo 'success' || echo 'failure'
# Example:
#   $ do_ask "are you sure?" && echo "***ok***"
#     are you sure? [y|n] (default=y) y
#     ***ok***
#
do_ask() {
  local yn='y' allow_quit=false opts='[y|n]'

  [ "$1" = "-q" ] && shift && allow_quit=true && opts='[y|n|q]'

  read -N 1 -s -p "$@ $opts (default=y) " yn

  [ "$yn" = "y" -o -z "$yn" ] \
      && printf " [answer=$yn => yes]\n" 1>&2 \
      && return 0

  $allow_quit && [ "$yn" = "q" ] \
      && printf " [answer=$yn => QUIT]\n" 1>&2 \
      && return 2

  printf "\n" 1>&2

  return 1
}

do_ask "$@"

