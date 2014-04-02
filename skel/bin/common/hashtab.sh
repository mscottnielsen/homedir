#!/bin/bash
#
# Persistent bash hashtable. Can either be run as a script, or
# source the file to use the following functions:
#
#----------------------------------------------------------------
# create the hash (not necessary; you can just start using 'addhash')
# $ newhash foobar
#
# add entries:
# $ addhash foobar key9 value9
# $ addhash foobar testing 'value 1234'
#
# access value by key
# $ gethash foobar key9    # ---> value9
#
# show all keys
# $ keyshash foobar        # ---> key9 testing
#----------------------------------------------------------------
#
# Internal storage example:
#  _hashtable_foobar=/tmp/.tmphash.{username}.{tty}/{hashtable_name}
# where tty is the terminal number (0, 1, 2...), username is the login name,
# and hashtable_name is a directory, which is the name of the hashtable.
# keys and values are:
#   dir_prefix/{hashtable_name}/{key}   <=== file {key} contains value
#
# Example: hash table: "employee", key: "name" value: "joe smith"
#   $ addhash employee name 'joe smith'
#   $ tty
#   /dev/pts/6
#   $ cat /tmp/.tmphash.jsmith.6/employee/name
#   joe smith


_hashtab_usage() {
  local fp=${BASH_SOURCE[0]}
  local p=${fp##*/}
   cat<<EOF
   Persistent hashtable in bash; to use, either source this file to use the
   functions directly,
     . $fp
     addhash employees mnielsen 'sf office'  # store key/value
     gethash employees mnielsen              # get value by key
     keyshash employees                      # prints keys

   Or just run as a script:
     $p employees mnielsen 'sf office'  # store key/value
     $p employees mnielsen              # get value by key
     $p employees                       # prints keys
EOF
}

######################################################################
# (private function) log msg to stderr, only if verbose is enabled
#
_hashtab_log() {
  [ ${_hashtab_verbose:-0} -le 0 ] && return 0
  printf "[$(date)|$(tty)|$$|${FUNCNAME[2]}/${FUNCNAME[1]}| $*\n" 1>&2
  return 0
}


######################################################################
# (private function) return name of hashtable data store directory.
# either returns basename of whole directory, or if given an argument,
# the path to a single hashtable.
#
_hashtab_dir() {
  local tty=$(tty)
  local p="${TMPDIR:-"/tmp"}/.tmphash.${LOGNAME:-$USER}.${tty//[^0-9]/}"
  [ $# -gt 0 ] && p="${p}/$1"
  echo "$p"
}

######################################################################
# (private function) init hashtable by name (called by other functions).
# creates data store directory if it doesn't exist.
#
_get_hashtab() {
  [ $# -lt 1 ] && printf "** error: expecting hash name\n" 1>&2 && return 1
  local name="$1"
  local varname="_hashtable_${name}"
  local hashdir=$(eval "echo \"${!varname}\"")

  _hashtab_log " varname=$varname\n existing hashdir=$hashdir"

  [ ${name:0:1} = "-" ] \
    && printf "** error: invalid hashtable name: $name\n" 1>&2 \
    && return 1

  if [ ${#hashdir} -eq 0 ]; then
    hashdir=$(_hashtab_dir "$name")
    _hashtab_log " varname=$varname\n (tty=$(tty)) mkdir hashdir=$hashdir"
    eval "export ${varname}=${hashdir}"
    [ ! -d "$hashdir" ] && mkdir -p "$hashdir"
  fi
  echo $hashdir
  return 0
}


######################################################################
# Usage: newhash hash_name
# Creates per-user and per-tty store for values
# in $TMPDIR, by default /tmp;
# hash_name should be a valid filename.
#
newhash () {
  [ $# -lt 1 ] && printf "** error: expecting hash name\n" 1>&2 && return 1
  #[ $# -gt 0 -a "$1" = "-v" && _hashtab_verbose=1
  local hashdir=$(_get_hashtab "$1")
  test -d "$hashdir"
}
typeset -fx newhash

######################################################################
# Usage: delhash hash_name [key]
# Either delete the whole hashtable, or just the given key
#
delhash () {
  #set -x
  [ $# -lt 1 ] && printf "** error: expecting hash name\n" 1>&2 && return 1
  local hashdir=$(_get_hashtab "$1")
  if test -d "$hashdir"; then
    echo "$hashdir" | egrep "^/tmp/.*$LOGNAME" \
      && echo "deleting: $hashdir" \
      && rm -r "$hashdir"
  fi
  #set +x
}
typeset -fx delhash

######################################################################
# Usage: addhash hash_name key value
# Sets hash value for given hashtable, key and value
# Example:
#  $ addhash employee mike 'sf office 1234'
#  $ gethash employee mike
#  sf office 1234
#
# Optionally, pass in an expression that will be evaluated in the
# background, available at a later date. Examples:
#  (1)
#  # addhash returns immediately, but is being calculated. Might or might
#  # not be available when requested, but old value is immediately deleted.
#  $ addhash -b employee jversion 'java -version 2>&1 | head -1'
#  $ gethash employee jversion  # --> now available
#  java version 1.5.0_22
#
#  (2)
#  $ addhash -b employee mike  "$HOME/bin/calc_bonus_longtime.sh"
#  $ gethash employee mike  # --> first time, returns nothing while calculating
#                                 (previous value immediately deleted)
#  $ gethash employee mike  # --> second time, script is finished
#  123456
#
#
addhash () {
  [ $# -lt 3 ] && printf "** error: expecting hash name, key and value\n" 1>&2 && return 1
  local async=0
  [ $# -gt 2 -a "$1" = "-b" ] && async=1 && shift
  local name=$1
  export key=$2
  shift 2
  export val="$@"
  export hashdir=$(_get_hashtab $name)
  if [ $async -eq 0 ]; then
    _hashtab_log " sync write: hashdir=$hashdir key=$key / value=$val"
    printf "$val\n" > "$hashdir"/"$key"
  else
    _hashtab_log " async write: hashdir=$hashdir key=$key / value=$val"
    ( eval "$val 2>&1" > "$hashdir"/"$key" & )  >/dev/null 2>&1
  fi
}
typeset -fx addhash

######################################################################
# Usage: gethash hash_name key
# Returns hash value for given hashtable and key
# Example: addhash employee mike  # --> returns 'sf office 1234'
#
gethash () {
  [ $# -lt 2 ] && printf "** error: expecting hash name and key\n" 1>&2 && return 1
  #set -x
  local name=$1 key=$2
  local hashdir=$(_get_hashtab "$name")
  local val=""
  [ -f "$hashdir"/"$key" ] && val=$(cat "$hashdir"/"$key") && eval "echo \"$val\""
  #set +x
}
typeset -fx gethash

######################################################################
dumphash () {
  local x y hashdir=$(_hashtab_dir ${1:-"*"})
  for x in  $(eval echo $hashdir ); do
     [ $# -eq 0 ] && printf "#==== $(basename $x) \n"
     [ -e $x ] && for y in $(ls $x)
        do
           printf "${y}: \'$( cat $x/$y )\'\n"
        done
  done 1>&2
}
typeset -fx dumphash

######################################################################
# Usage: keyshash hash_name
# Returns list of all keys defined for hash name.
# Example: keyshash employee   # --> returns mike
#
keyshash () {
  [ $# -lt 1 ] && printf "** error: expecting hash name\n" 1>&2 && return 1
  local name=$1
  local val=""
  local hashdir=$(_get_hashtab "$name")
  [ -e "$hashdir" ] && val=$(ls "$hashdir") && eval "echo \"$val\""
}
typeset -fx keyshash

######################################################################
# dump whole keystore, or just one hashtable by name
#
_hashtab_dump() {
  local hashdir=$(_hashtab_dir ${1:-"*"})
  printf "# =====================================\n" 1>&2
  printf "# dump hashtab $@ (tty=$(tty)) $hashdir =>\n" 1>&2
  dumphash $@ 1>&2
  printf "# =====================================\n\n" 1>&2
}


######################################################################
# Usage as a script:
#
#  three args, assume "put" with given hastable & key
#    $ hashtab.sh htable foo bar
#
#  two args, assume "get" with given hastable & key
#    $ hashtab.sh htable foo
#    bar
#
#  one arg, print keys
#    $ hashtab.sh htable
#
hashtab_main() {
  while getopts hvd opt; do
    case "$opt" in
    h) _hashtab_usage
       exit 1
      ;;
    d) _do_hashtab_dump_store=1
      ;;
    v) _hashtab_verbose=1
      ;;
    *)
      echo "unknown option" 1>&2 && usage && exit 2
      ;;
    esac
  done; shift $((OPTIND-1)); OPTIND=1


  [ "$_do_hashtab_dump_store" != "" ] &&  _hashtab_dump $1

  if [ $# -ge 3 ]; then
    addhash "$@"
    exit $?
  elif [ $# -eq 2 ]; then
    gethash "$@"
    exit $?
  elif [ $# -eq 1 ]; then
    keyshash "$@"
    exit $?
  fi
}

HOMEDIR_BIN_COMMON_HASHTAB_INIT=1

# either run as script, or juse use functions by sourcing file (return true)
[ $# -ge 0 ] && hashtab_main "$@" || :


