#!/bin/bash

# (File to be sourced, not run as a script.) Source env file(s), but only
# if not already sourced. Log status, duration of execution, etc to logfile

[ ${HOMEDIR_BIN_COMMON_LOG_INIT:-0} -eq 0 ] && source $HOMEDIR_BIN/common/log.sh >> $HOMEDIR_LOG 2>&1

############################################################################
# source the given env file, log errors & elapsed time
_source_env() {
  _source_env_log() { 
     local LOG_LEVEL=INFO
     local lvl=$1
     shift
     log $lvl "$@"
  }

  # passed from parent function: verbose=true print_sec=true
  [ "$1" = "-q" ] && verbose=false && shift
  [ "$1" = "-s" ] && print_sec=false && shift
  # construct/set variable based on filename, indicating if the env file
  # has already been sourced: some/var/foo.env => some_var_foo_env=1
  local envfile=$1
  local var=${envfile//[^a-zA-Z]/_}
  local done=${!var}
  local ts_lap=$(h_tstamp)   # log start/elapsed time (h_tstamp from bashrc)

  _source_env_log DEBUG "source_env: $*"

  [ "${done:-0}" -ne 0 ] \
      && { _source_env_log DEBUG "...already loaded: $envfile ($var=$done)";
           return 0 ; }

  eval "${envfile//[^a-zA-Z]/_}=1"

  if [ -f "$envfile" ]; then
    #_source_env_log DEBUG "...loading: $envfile"
    $verbose && printf "   loading \"$envfile\""             #>> $HOMEDIR_LOG 2>&1
    source $envfile || printf "(**error ($?): \"$envfile\")" #>> $HOMEDIR_LOG 2>&1
    $print_sec && printf "($(( $(h_tstamp) - ts_lap))s)"
  elif [ ${#VERBOSE} -gt 0 ]; then
    _source_env_log DEBUG "...not found: $envfile"
    $verbose && printf "   **warning: \"$envfile\" not found. ($(( $(h_tstamp) - ts_lap ))s)\n"
  fi
}

############################################################################
# for each file...
_source_all_env() {
  export verbose=true print_sec=true
  [ "$1" = "-q" ] && verbose=false && shift
  [ "$1" = "-s" ] && print_sec=false && shift
  [ "$1" = "-q" ] && verbose=false && shift
  local num=$#

  for f ; do
    _source_env $f
  done
  [ $num -gt 1 ] && [ "$verbose" = "true" -o $print_sec = "true" ] && h_log "source-env/done." "\n"
}

############################################################################
# main
_source_all_env $@

# return success
:

