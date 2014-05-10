#!/bin/bash
#
# Persistent hashmap, mapping keys to values, stored in files. Values may
# be stored and calculated in the background to be retrieved later.
# Every hashtable is uniquely named, so separate maps may be kept.
# By default, storage is separated per-user and per-tty.
#
# The functions can be used directly. Specify the command (put/get/rm/dump/keys),
# the hashtable name, and arguments.
#  * hashtab new {map}
#  * hashtab put {map} {key} {value} (alias: add)
#  * hashtab rm  {map} {key}
#  * hashtab get {map} {key}
#  * hashtab dump [{map}]
#  * hashtab keys {map}
#
# Sample usage (functions):
#   # creating the map is optional; just 'add' to create a new map
#     $ hashtab new foo
#   # add (put) entries to a map: hashtab put {map} {key} {value}
#     $ hashtab put foo key23 value23
#     $ hashtab put foo test23 'value 1234'
#   # get value by key
#     $ hashtab get foo key23    # ---> value23
#   # show all keys
#     $ hashtab keys foo         # ---> key23 test23
#
# Sample usage (script):
#   $ hashtab.sh put employees michael 'sf office'  # store key/value
#   $ hashtab.sh get employees michael              # get value by key
#   $ hashtab.sh keys employees                     # prints keys
#
# All data storage is in a single directory; every named hashtable has its own
# subdirectory. Each value is stored in a file with the key as the filename.
#
# Variables:
#   Uses $HASHDIR for data directory; if not set, use $TMPDIR; by default /tmp
#   Changing the global HASHDIR causes everything using the hashtab
#   script/functions (in the current shell), to begin writing to the new data
#   storage directory.
#
# Example hashtable "employee", key: "name" value: "jane doe"
#   $ export HASHDIR=~/temp/hash
#   $ . ~/bin/common/hashtab.sh
#   $ hashtab put employee name 'jane doe'
#   $ hashtab get employee name
#   jane doe
#   $ tty
#   /dev/pts/8
#   $ cat $HASHDIR/.tmphash/user-msnielse/term.8/employee/name
#   jane doe

######################################################################
# (Internal) log to stderr if only verbose is enabled
_hashtab_log() {
  [ ${HASHTAB_VERBOSE:-0} -le 0 ] && return 0
  printf "[$(date)|$(tty)|$$|${FUNCNAME[2]}/${FUNCNAME[1]}| $*\n" 1>&2
  return 0
}

_hashtab_fun() {
    echo "${FUNCNAME[1]}" | sed 's/_/ /g' | sed 's/^ *//'
}

stacktrace () {
   echo "stack:"
   local i=0
   while caller $i ; do
      i=$((i+1))
   done
   echo "FUNC=${FUNCNAME[*]}"
}

######################################################################
# (Internal) return basename of hashtable data directory, or if given
# an argument, the path to the given hashtable. Env vars:
#  HASHDIR      - data directory
#  HASHDIR_TERM - if set, use a global directory for all terminals
#                   with this name. By default, uses `tty`
#  HASHDIR_USER - if set, use a global directory for all users
#                   with this name. By default, uses $LOGNAME or $USER
# Call _get_hashtab instead to return the name *and* create the
# directory, should it not already exist.
#
_hashtab_dirname() {
  # if multiple users on same host, .tmphash must be writable for all, or unique per user
  local ret tmpd=${TMPDIR:-"/tmp"}
  local dir=${HASHDIR:-"$tmpd"}/.tmphash-"${LOGNAME:-$USER}"
  local user=user-${HASHDIR_USER:-"${LOGNAME:-$USER}"}
  local tty=$HASHDIR_TERM
  local name=

  usage() {  cat<<EOF 1>&2
  ** Usage: _hashtab_dirname [-T {term}][-U {user}][-v][-h] {hash_store}
       Prints hashtable directory, for the given hash table.
         -T {term} - re-use the same hashtable for the given tty
         -U {user} - re-use the same hashtable for the given user
         -h          print help usage
         -v          verbose logging
EOF
    [ $# -gt 0 ] && { echo "error: given($#): $@" 1>&2 ; } # stacktrace 1>&2; }
    return 0
  }

  while getopts hT:U:v opt; do
    case "$opt" in
      h) usage; return 2;;
      T) tty=$OPTARG;;
      U) user=user-${OPTARG};;
      v) verbose=true;;
      *) echo "** unknown option ($@)" 1>&2; usage $*; return 2;;
    esac
  done; shift $((OPTIND-1)); OPTIND=1

  name=$1

  [ "${name:0:1}" = "-" ] && { usage "malformed hashtable name (can't start with '-'): given name=$name ($@)"; return 1; }

  [ "$HASHDIR_TERM" != "" -a "$tty" = "" ] \
    && _hashtab_log "** warning: HASHDIR_TERM=$HASHDIR_TERM; using common data directory for all terminals"
  [ "$tty" = "" ] && { tty=$(tty); tty=${tty//[^0-9]/}; }

  ret="${dir}/${user}/term.${tty}"
  [ $# -gt 0 ] && ret="${ret}/$name"

  echo "$ret"
}

######################################################################
# (Internal) initialize named hashtable, create data directory if
# necessary. Return hashtable data directory.
#
_get_hashtab() {
  _hashtab_log "_get_hashtab:hashtab_dirname: $*"
  local hashdir
  hashdir=$(_hashtab_dirname $*) || { echo "** error: can't make storage directory (given: $*)"  1>&2; return 2; }
  [ "$hashdir" = "" -o "${hashdir:0:1}" = "-" ] && { echo "** error: can't make storage directory: \"$hashdir\"" 1>&2; return 2; }
  [ ! -d "$hashdir" ] && mkdir -p "$hashdir"
  echo "$hashdir"
  return 0
}

######################################################################
# Usage: hashtab_new {hash_name}
# hash_name should be a valid filename.
#
#_hashtab_new () {
#  [ $# -lt 1 ] && printf "** [$(_hashtab_fun)] error: expecting hash name\n" 1>&2 && return 1
#  local hashdir=$(_get_hashtab $*)
#  test -d "$hashdir"
#}
#
######################################################################
# Usage: hashtab_rm {dir} {hash_name} [key]
# Either delete the whole hashtable, or just the given key
#
_hashtab_rm () {
  local rm_opts opt OPTIND OPTARG
  local hashdir name key to_remove=hashtab_entry verbose=false ret=1
  [ $# -eq 0 ] && { printf "** [$(_hashtab_fun)] error: expecting {directory} {hash_name}\n" 1>&2 ; return 2; }
  hashdir=$1
  shift

  usage() { printf "** [$(_hashtab_fun)] error: expecting {hash_name} {key}\n" 1>&2 ; return 0; }
  [ $# -eq 0 ] && { usage; return 2; }

  while getopts iv opt; do
    case "$opt" in
      i) rm_opts="-i"; verbose=true;;
      v) verbose=true;;
      *) usage; echo "** [$(_hashtab_fun)] unknown option: $@" 1>&2; return 2;;
    esac
  done; shift $((OPTIND-1)); OPTIND=1

  [ $# -lt 1 ] && { usage; return 2; }

  name=$1
  key=$2

  [ $# -gt 1 ] && to_remove="$hashdir/$key" || to_remove=$hashdir

  if test -e "$to_remove"; then
    if echo "$to_remove" | egrep "tmphash" 1>/dev/null
    then
      $verbose && printf "storage: ${to_remove}\n"
      rm $rm_opts -r "$to_remove" && ret=0
      test -e "$to_remove" && ret=1
      $verbose && [ $ret -eq 0 ] && echo "deleting: $to_remove (status=$ret)" 1>&2
      $verbose && [ $ret -ne 0 ] && echo "not deleting: $to_remove (status=$ret)" 1>&2
      return $ret
    else
      $verbose && echo "not deleting (data is not in tmp hash directory): $to_remove" 1>&2
      return $ret
    fi
  else
      $verbose && printf "storage: ${to_remove}\n"
      $verbose && printf "** error: entry does not exist: map=$name / key=$key\n" 1>&2
  fi
  return 1
}

######################################################################
# Usage: hashtab_add {dir} {hash_name} {key} {value}
# Set value on given hashtable, for given key.
# Example:
#  $ hashtab_add {dir} employee mike 'sf office 1234'
#  $ hashtab_get {dir} employee mike
#  sf office 1234
#
# Optionally, pass in an expression that will be evaluated in the
# background, available at a later date.
# Example:
#   'put' returns immediately, but is being calculated. Might not yet be
#    available when requested, but old value is immediately deleted.
#   $ hashtab_add -b employee jversion 'java -version 2>&1 | head -1'
#   $ hashtab_get employee jversion  # --> now available
#   java version 1.5.0_22
#
# Example:
#   $ hashtab_add -b {dir} employee mike  "$HOME/bin/calc_bonus_longtime.sh"
#   $ hashtab_get {dir} employee mike  # --> returns nothing while calculating
#                                      #     (previous value immediately deleted)
#   $ hashtab_get {dir} employee mike  # --> script is finished
#   123456
#
_hashtab_put () {
  local opts opt OPTIND OPTARG
  local name key exe=false async=false verbose=false hashdir=$1
  shift

  usage() {
      [ $# -gt 0 ] && printf "** error: $@\n" 1>&2
      printf "** usage: hashtab_put [opts] {hash_name} {key} {value}\n" 1>&2
  }

  _hashtab_log "parse args: hashdir=$hashdir (args=$@)"

  while getopts behtu opt; do
    case "$opt" in
      b) async=true;;
      e) exe=true;;
      h) usage; return 2;;
      v) verbose=true;;
      *) usage "unknown option: $@"; return 2;;
    esac
  done; shift $((OPTIND-1)); OPTIND=1

  name=$1
  key=$2
  shift 2

  [ "${name:0:1}" = "-" ] && { usage "malformed hashtable name (can't start with '-'): name=$name, key=$key, value=$@"; return 1; }
  [ $# -eq 0 ] && { usage "missing arguments; given: name=$name, key=$key, value=$@"; return 1; }

  if $async; then
    _hashtab_log " async write: hashdir=$hashdir key=$key / value=$@"
    ( eval "$@" > "$hashdir"/"$key" 2>&1 & ) >/dev/null 2>&1
  elif $exe; then
    _hashtab_log " exec write: hashdir=$hashdir key=$key / value=$@"
    ( eval "$@" > "$hashdir"/"$key" 2>&1 ) >/dev/null 2>&1
  else
    _hashtab_log " const write: hashdir=$hashdir key=$key / value=$@"
    printf "$@\n" > "$hashdir"/"$key"
  fi
}


######################################################################
# Usage: hashtab_get {dir} hash_name key
# Returns hash value for given hashtable and key
#
_hashtab_get () {
  local opts opt OPTIND OPTARG
  local name key val default_value hashdir verbose=false
  [ $# -eq 0 ] && { printf "** [$(_hashtab_fun)] error: expecting {directory} {hash_name} {key} {value} [{default}]\n" 1>&2 ; return 1; }
  hashdir=$1
  shift

  usage() {
    printf "** usage: {hash_name} {key} [{default_value}]\n" 1>&2
    printf "**  return the key's value; or if unset, set and return the default value\n" 1>&2
  }

  name=$1
  key=$2
  default_value=$3
  val=""

  #set -x
  #_hashtab_log "map=$name / key=$key / value=$val / hashdir=$hashdir"

  [ $# -lt 2 ] && { usage; return 1; }

  if [ -f "$hashdir"/"$key" ]; then
      val=$(cat "$hashdir"/"$key") && eval "echo \"$val\""
      _hashtab_log "map=$name; found value for key; key=$key / value=$val (hashdir=$hashdir)"
  elif [ $# -gt 2 ]; then
      _hashtab_log "map=$name; no value for key; using default: key=$key / value=$val / default=$default_value (hashdir=$hashdir)"
      _hashtab_put "$hashdir" "$name" "$key" "$default_value"
      [ -f "$hashdir"/"$key" ] && val=$(cat "$hashdir"/"$key") && eval "echo \"$val\""
  fi
  #set +x
  [ "$val" = "" ] && return 1 || return 0
}


######################################################################
# Dump to stderr, either entire store or the single given hashtable.
# Dumps in json format. Hidden hashtables only printed
# if explicitly requested by name (e.g., "_hashtab_dump {dir} [-l] .hidden")
# Options:
#  -l   dump to single line, rather than pretty-print
#
_hashtab_dump () {
  local opts opt OPTIND OPTARG
  local name key val hashdir oneline=false do_escape=false
  [ $# -gt 0 ] && hashdir=$1 && shift
  [ $# -gt 0 ] && name=$1 && shift
  [ $# -gt 0 -a "$1" = "-l" ] && oneline=true && shift

  usage() { echo "** usage: _hashtab_dump {directory} [-l] [name]" 1>&2; }

  if $do_escape ; then  # not implemented
      escape () { sed 's/$/\\\\n/; s/"/\\\\"/g'; }
  else
      escape () { cat; }
  fi

  if $oneline ; then  # print one line, strip indentation
      shift
      printf "{" 1>&2
      reformat_space() {
         # hp-ux tr/sed bug; need newline after tr for sed to work
         sed 's/^ *//' | { tr -d '\12'; echo; } | sed 's/,}/}/g; s/,$//g' | tr -d '\12'
      }
  else               # pretty-print json, with indentation
      printf "{\n" 1>&2
      reformat_space() { cat; }
  fi

  for x in $(echo $hashdir/$name); do
      printf " \"$(basename $x)\": "
      if [ -e $x ]; then
          printf "{\n"
          for y in $(ls $x); do
              printf "   \"${y}\": \"$(cat "$x"/"$y" | escape)\",\n"
          done
          printf " },\n"
      else
          printf " null\n"
      fi
  done | reformat_space 1>&2
  printf "}\n" 1>&2
}


######################################################################
# Usage: _hashtab_keys {dir} hash_name
# Return all keys defined for hash map
# Example: _hashtab_keys {dir} employee   # --> returns: larry moe curly
#
_hashtab_keys () {
  local val name hashdir
  [ $# -eq 0 ] && { printf "** [$(_hashtab_fun)] error: expecting {directory} {hash_name}\n" 1>&2 ; return 1; }
  hashdir=$1
  shift
  [ $# -ne 1 ] && { printf "** [$(_hashtab_fun)] usage: {hash_name}\n" 1>&2 ; return 1; }
  name=$1  # technically don't need this, since it's already part of $hashdir
  [ -e "$hashdir" ] && val=$(ls "$hashdir") && eval "echo \"$val\""
}

######################################################################
# Usage as a script, same as w/ functions:
#  "put" w/ hastable & key: $ hashtab.sh put htable foo bar
#  "get" w/ hastable & key: $ hashtab.sh get htable foo # => bar
#  print hashtable keys:    $ hashtab.sh keys htable
#
hashtab() {
  local opt OPTIND OPTARG
  local fp=${BASH_SOURCE[0]}
  local prog=${fp##*/}
  local opts opt_user opt_term
  local hashdir hash_name key value
  local do_dump=false ret=0 cmd=unset


  hashtab_usage() { cat<<EOF 1>&2
   Usage: $prog {put|get|rm|keys|dump} [opts] {hash_name} [key] [value]

   Persistent hashtable in bash; keys/values stored in a temp directory.

   Arguments/Options:
     get {store} {key} {default} - get value for key; store default if not found.
     put [-b|-e] {store} {key} {val} - store key/value. Use "-e" to execute
                                   value as command, "-b" in background.
     rm  {store} {key}           - remove value for key.
     keys {store}                - print all keys for the given store
     dump [{store}]              - print entire store, or all stores

   Example:
     $ $prog put  emp michael  'SF office'  # store key/value
     $ $prog get  emp michael               # get value for key
     $ $prog keys emp                       # prints keys for store
     $ $prog put -b emp john  calc_value.sh # execute in bg, store results

   To use the functions directly (sourcing the script):
     $ . $prog
     $ hashtab put  emp michael  'SF office'  # store key/value
     $ hashtab get  emp michael               # get value by key
     $ hashtab keys emp                       # prints keys

   Advanced options:
     -h         print help usage.
     -i         when removing, ask for confirmation
     -l         print dump as single line (json)
     -t         store key/value for all terminals, not just current
     -T {term}  store key/value given terminal
     -u         store key/value for all users, not just current
     -U {term}  store key/value given user
     -v         verbose

  Current storage directory: $(_get_hashtab $opt_term $opt_user "$name")
EOF
  return 0
  }

  [ $# -gt 0 -a "${1:0:1}" != "-" ] && cmd=$1 && shift

  while getopts bdehiltT:uU:v opt; do
    case "$opt" in
      b) opts="$opts -b";;
      d) do_dump=true
         cmd=dump;;
      e) opts="$opts -e";;
      h) cmd="help";;
      i) opts="$opts -i";;
      l) opts="$opts -l";;
      t) opt_term="-T all";;
      T) opt_term="-T $OPTARG";;
      u) opt_user="-U all";;
      U) opt_user="-u $OPTARG";;
      v) opts="$opts -v";; #HASHTAB_VERBOSE=1
      *) echo "** unknown option ($@)" 1>&2
         cmd=help;;
    esac
  done; shift $((OPTIND-1)); OPTIND=1

  [ "$cmd" = "unset" ] && { cmd=$1; shift; }

  name=$1
  key=$2
  _hashtab_log "***[hashtab] make hashdir: opt_term=$opt_term opt_user=$opt_user name=$name / opts=$opts"
  hashdir=$(_get_hashtab $opt_term $opt_user "$name") || return 2

  _hashtab_log "***[hashtab] map=$name / key=$key / cmd=$cmd / hashdir=$hashdir"

  case "$cmd" in
      "add" | "put")
            _hashtab_put "$hashdir" $opts "$@"
            ret=$?
            ;;
      "get")
            _hashtab_get "$hashdir" $opts "$@"
            ret=$?
            ;;
      "keys")
            _hashtab_keys "$hashdir" $opts "$@"
            ret=$?
            ;;
      "rm")
            _hashtab_rm "$hashdir" $opts "$@"
            ret=$?
            ;;
      "dump")
            do_dump=true
            ;;
      "help")
            echo "** print usage (cmd=$cmd options=\"$@\")";
            hashtab_usage
            ret=$?
            ;;
      *) echo "** unknown command (cmd=$cmd options=\"$@\")";
            hashtab_usage
            #echo =================
            #. ~/bin/cstack.sh
            #echo =================
            return 2
            ;;
  esac

  if $do_dump ; then
      _hashtab_dump $(_get_hashtab $opt_term $opt_user) "${name:-*}" $opts
  fi
  return $ret
}
typeset -fx hashtab

HOMEDIR_BIN_COMMON_HASHTAB_INIT=1

# run as script or as functions by sourcing the file (return true)
[ $# -gt 0 ] && hashtab "$@" || :

