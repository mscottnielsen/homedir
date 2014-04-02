#!/bin/bash
#
# implement 'find -maxdepth' functionality for older, non-gnu solaris
#

#########################################################
_find_maxdepth() {
  # usage: find_maxdepth {num} {dir}
  # return true(0) if dir is greater than {num} directories (in order to "-prune"
  # the search). If num=0, return false(1) (for unlimited depth, i.e, no pruning)

  local max=$1 arg=$2
  [ $max -eq 0 ] && return 1
  arg=${arg%[/]}        # remove trailing "/"
  arg=${arg//[^\/]/}    # remove all except "/"
  arg=${#arg}           # count all "/"
  (( arg >= max   ))
}
export -f _find_maxdepth

#########################################################
find_max() {
  # Run find, limiting search depth to 'n' directories (-maxdepth, for platforms
  # that do not implement this feature). Start search from "." by default.
  # Allow either format:
  #    find_max -maxdepth n dir1 dir2 ... -print
  #    find_max dir1 dir2 -maxdepth n ... -print

  local sdir depth

  [ $# -ge 2 -a "$1" = "-maxdepth" ] && depth=$2 && shift 2

  for x; do
    [ "${x:0:1}" = "-" ] && break             # found option (starts with "-")
    sdir="${sdir} ${x}" && shift && continue  # e.g., directories
  done

  [ $# -ge 2 -a "$1" = "-maxdepth" ] && depth=$2 && shift 2

  find ${sdir:-.} \( -type d -a -exec bash -c '_find_maxdepth "$1" "$2"' - ${depth:-0} {} \; -prune \) -o "$@"
}

#########################################################
find_max "$@"

