#!/bin/bash

usage() {
  cat<<EOF
  Run git clone into a subdirectory named after the
  project owner (i.e., the first part of the repo URL).

  Usage: $PROG [-h|-n] repo [repo2,...]
    -h   print help and exit
    -n   dry-run, print what would be run, then exit

  Example:
     Create git clone in subdir: owner/project/...
     $PROG  git@github.com:owner/project.git
     $PROG  https://github.com/owner/project.git
     $PROG  ssh://user@example.com/owner/project.git
EOF
  [[ $1 = "exit" ]] && exit 2
  return 0
}

do_clone() {
  # do git clone {url} into subdir "a/b/foo" if {url} is like:
  #  * git@github.com:a/b/foo/bar.git
  #  * https://github.com/a/b/foo/bar.git
  #  * ssh://user@host.com/a/b/foo/bar.git"
  # (the "a/b/" could be trimmed from the subdir, but not typically there)

  local repo dir tmp proj url=$1

  if echo "$url" | egrep -q '[^/:]+@[^/:]+:'; then
    # git@gitlab.com:foo/bar.git => foo/bar.git
    repo="${url#*:}"
  elif echo "$url" | egrep -q 'http.*://|ssh://'; then
    # eg ssh://user@host.com/foo/bar.git => foo/bar.git
    repo="${url#*\.com\/}"
  else
    printf "\n** error: unrecognized git clone {repo} format: ${url}\n\n" 1>&2
    usage
    return 1
  fi

  dir=${repo%/*}
  tmp=${repo#*/}
  proj=${tmp%.*}

  # checkout git repo into subdirectory
  printf "\n# == dir:  ${dir}\n# == proj: ${proj}\n# == url:  ${url}\n"
  ( $RUN mkdir -p "$dir" &&
    $RUN cd "$dir" &&
    $RUN git clone "$url" &&
    $RUN cd -
   ) || { printf "\n\n** error: git clone \"$url\"\n\n"; rmdir "$dir"; return 1; }

  return 0
}

run_test() {
  printf "\n== basic tests ===========\n"
  $PROG -n 'git@github.com:owner/project.git'
  $PROG -n 'foo@gitlab.com:owner/project.git'
  $PROG -n 'foo@example.org:owner/project.git'
  $PROG -n 'ssh://user@example.com/owner/project.git'
  $PROG -n 'https://github.com/owner/project.git'
  printf "\n== subdirs tests =========\n"
  $PROG -n 'foo@gitlab.com:a/b/owner/project.git'
  $PROG -n 'https://github.com/a/b/owner/project.git'
  $PROG -n 'ssh://user@example.com/a/b/owner/project.git'
}

RUN=
PROG=${BASH_SOURCE[0]##*/}

[[ $1 = "-t" ]] && usage && run_test && exit
[[ $1 = "-n" ]] && RUN=echo && shift
[[ $1 = "-h" || $# = 0 ]] && usage exit

for arg; do
  do_clone "$arg" || exit 1
done

