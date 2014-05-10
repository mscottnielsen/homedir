#!/bin/bash
#
# Generic logging for bash scripts. Call as script with message to log,
# or source this file to reuse the functions from another script.
#
# Example called as script:
#    log.sh [ERROR|INFO|DEBUG|TRACE] "message..."
#
# Example called as function (from another script):
#   . $HOMEDIR_BIN/common/log.sh # source this file (see below)
#   LOG_LEVEL=INFO               # set level={NONE, ERROR, WARN, INFO, DEBUG}
#   log INFO "message..."        # arguments: log [ERROR|INFO|DEBUG|TRACE] ...
#   echo "msg..." | log INFO     # or, log via stdin
#
# Note: to conditionally source this file to initialize the functions (maybe
# speeding up initialization a bit):
#  [ ${HOMEDIR_BIN_COMMON_LOG_INIT:-0} -eq 0 ] && source $HOMEDIR_BIN/common/log.sh
#########################################################################

# Environment variables:
#   LOG_LEVEL={NONE|ERROR|WARN|INFO|DEBUG|TRACE}
#        Determine which log messages are logged. Default: INFO
#   LOG={/path/to/logfile}
#        Set output log file. Example: /tmp/log_{user}_{script_name}.log
#   LOG_DIR=/tmp
#        Directory to write logfile to. Default is $HOME/temp
#   LOG_CONSOLE=1
#        Log to stderr, in addition to log file. Default is 0 (disabled).
#   LOG_MAX_SZ=1024
#        Size (in KB) to truncate log file. Default is 1024.

: ${LOG_LEVEL:=INFO}     # set to: ERROR, WARN, INFO, DEBUG, TRACE (or NONE)
: ${LOG_MAX_SZ:=1024}    # approx max log size in KB (infinite: LOG_MAX_SZ=0)
: ${LOG_CONSOLE:=0}      # set LOG_CONSOLE=1 to log to stderr
: ${LOG_TRUNC:=1}        # set LOG_TRUNC=0 to disable log truncation (or LOG_MAX_SZ=0)

export LOG_USE_GNU_DATE  # if 'date' supports gnu options

#########################################################################
# standard format date, cross-platform test
_log_date() {
  if [ "${LOG_USE_GNU_DATE}" = "" ]; then
    date --rfc-3339=seconds 2>/dev/null 1>&2 \
        && export LOG_USE_GNU_DATE=1 \
        || export LOG_USE_GNU_DATE=0
  fi

  [ ${LOG_USE_GNU_DATE:-0} -eq 1 ] \
      && date --rfc-3339=seconds 2>/dev/null \
      || date '+%Y-%m-%d %H:%M:%S%z'
  return 0
}

_log_stmp() {
    local tty=${h_tty:-$(tty)}
    printf "$(_log_date)|$tty"
}

#########################################################################
# Return full path of script that sourced/called this script. Options:
#   -n   (default) return calling script name, as invoked (could be relative path)
#   -b   return only script name (i.e., basename)
#   -d   return the directory of calling script (i.e., dirname)
#   -s   return simplified / stripped version of script name (remove irregular chars)
#   -S   return simplified / stripped version of calling FUNCTION name (remove irregular chars)
#   -h   help/usage
#
_log_prog() {
  local prog=${BASH_SOURCE[${#BASH_SOURCE[@]}-1]}  # script that sourced/called this file
  [ $# -eq 0 ] && printf "$prog\n" && return 0
  local prog_name="${prog##*/}"             # basename of script (strip path)
  local cstack
  local opt OPTIND OPTARG

  strip_name0() {
    sed 's/^ *//; s/ /_/g; s/\./_/g; s/[^-a-zA-Z0-9_]/_/g'
  }

  callstack() {
    echo $* \
        | sed 's/ /\n/g' \
        | egrep -v '^ *$|^source$|load_h_env_file|setup_user_env|/log.sh$|^main$|^_log_|^log$' \
        | sed 's/^.*\///' \
        | uniq
  }

  usage() {
    printf "\n Usage: _log_prog [-n|-b|-d|-h|-s|-S]
     Return program name, basename, dirname, etc. Options:
       -n  script name, as invoked (default)
       -b  basename of script
       -d  dirname of script
       -s  basename, remove non-alphanumeric chars (except underscore), suitable for variable name
       -S  call stack as string, remove spaces and some special characters\n\n"
  }

  while getopts bdhnsS opt ; do
    case "$opt" in
      b) printf "${prog_name}\n"
         ;;
      d) printf "$(cd "${prog%/*}" 2>/dev/null 1>&2 && pwd)\n" # same as: cd "$(dirname "$prog")" ...
         ;;
      s) printf "${prog_name//[^a-zA-Z0-9_]/_}\n"
         ;;
      S) cstack=$(echo $( callstack ${FUNCNAME[@]} ${BASH_SOURCE[@]} ) | strip_name0)
         echo "$cstack" | egrep '^[- \._]*$' 1>/dev/null \
             && printf "${prog_name//[^a-zA-Z0-9_]/_}\n" \
             || printf "$cstack\n"
         ;;
      n) printf "${prog}\n"
         ;;
      h) usage 1>&2
         ;;
      *) printf ERROR "** ($0) Error: unknown option given, args: $*" 1>&2
         #return 0  # should never get here (and returning false doesn't usually help)
         ;;
    esac
  done; shift $((OPTIND-1)); OPTIND=1
  return 0
}

#########################################################################
# Return full path to log file, {log_directory}/{log_filename}.log
# Directory: log to $LOG_DIR, by default $HOME/temp, putting logfiles in
# subdirectory log_${USER}. Options:
#    -d  {dir}  - use given directory for logfile.
#    -D         - use the calling script's directory for logfile.
# Log name is generated, based on calling script or function name. Options:
#    -f      use value of LOG for logfile, instead of generated logfile name.
#    -F name - don't use calling script/function to generate output log file
#            name; instead, use given value; eg: ${LOG_DIR}/log_${USER}_${nam}.log
#
_log_getfname() {
  local opt OPTIND OPTARG
  local default_filename=true generate_filename=true
  local log_userdir=log_${LOGNAME:-"$USER"}
  local log_basedir=${LOG_DIR:-"$HOME/temp"}
  local log_fname=default
  local lptr=LOG
  #local log    # log is from calling script, not local

  while getopts Dd:fF: opt ; do
    case "$opt" in
      f) default_filename=false
         generate_filename=true
         ;;
      F) default_filename=false
         log_fname=$OPTARG
         ;;
      d) log_basedir=$OPTARG
         ;;
      D) log_basedir=$(_log_prog -d)
         ;;
      *) echo "** error: unknown option getting logfile name ($(_log_prog) => ${FUNCNAME[@]})\n"
         ## return 1
         ;;
    esac
  done; shift $((OPTIND-1)); OPTIND=1

  if $generate_filename ; then
    if $default_filename ; then
      log_fname=$(_log_prog -S)  # calling fuction name/stack, reduced/simplified
      [ "$log_fname" = "" ] && log_fname=$(_log_prog -s)  # just use calling script name
    fi
    # logfile name stored in variable LOG_{script_name}, eg, LOG_foobar_sh=/tmp/log_foobar.log
    lptr=LOG_${log_fname//[^a-zA-Z0-9_]/_}
  fi

  log=${!lptr}

  if [ "$log" = "" ]; then
    log=${log_basedir}/$log_userdir/log_${LOGNAME:-"$USER"}_${log_fname}.log
  fi

  eval "export ${lptr}=\"${log}\""
  export ${lptr}=${log}

  printf "$log"
  return 0
}

#########################################################################
# Periodically truncate logfile. Returns true (0) if truncated, else false (1).
# Log truncation disabled if env var LOG_TRUNC=0 (enabled by default).
#
_log_check_truncate() {
  [ ${LOG_TRUNC:-1} -eq 0 -o ${LOG_MAX_SZ:-0} -le 0 ] && return 1
  local log=$1

  # setting SECONDS=0 after trunc would be better, but calling script may also use it.
  # z/OS quirk with du|cut, must use expr, and can't use: sz=$(du -sk $log | cut -f1)
  local sz=0 cnt=$((SECONDS % 60))
  [ $cnt -lt 3 -a -f "$log" ] \
      && sz=$( expr "$(du -sk $log)" : '[^0-9]*\([0-9]*\)' ) \
      && ((sz > LOG_MAX_SZ)) \
      && cat /dev/null >$log \
      && printf "[$(_log_stmp)|$FUNCNAME]: log truncated ($sz KB > LOG_MAX_SZ=$LOG_MAX_SZ KB)\n" >>$log \
      && printf "[$(_log_stmp)]==== Continue logging \"$(_log_prog)\" to: \"$log\"\n" >>$log \
      && return 0 \
      || return 1
}

#########################################################################
# Write output to $LOG, and also to stderr if LOG_CONSOLE=1
#
_log_output() {
  local log dir
  _log_getfname $@ >/dev/null # sets $log env var, also sets $LOG_{script}
  dir=${log%/*}
  mkdir -p "$dir"
  _log_check_truncate $log
  [ ${LOG_CONSOLE:-0} -eq 1 ] \
      && tee -a $log | sed "s:^:\[$log\]:" 1>&2 \
      || cat >> $log
  return 0
}


#########################################################################
# Log messages to log file at given logging level.
# If the log {level} is omitted, it defaults to "INFO".
# Usage: log [ERROR|INFO|DEBUG|TRACE] "message..."
#   or:  echo "message..." | log [ERROR|INFO|DEBUG|TRACE]
#
# Only log messages if level is greater than $LOG_LEVEL (default INFO).
# Valid levels: NONE, ERROR, WARN INFO, DEBUG, TRACE.
#
log() {
  # Strings mapped to log level numbers (prefixed w/ "LOG_" to avoid confusion)
  # (e.g., if foo="LOG_INFO", then ${!foo} == 2).  Default LOG_LEVEL="INFO"
  local fname fname_opt
  local LOG_NONE=0 LOG_ERROR=1 LOG_WARN=2 LOG_INFO=3 LOG_DEBUG=4 LOG_TRACE=5
  local msg_level_str="INFO" msg_level_var="LOG_INFO" current_level_var="LOG_${LOG_LEVEL}"
  local current_level=${!current_level_var}
  [ "$current_level" = "" ] && current_level=1
  local do_usage=false

  if [ $# -gt 0 ]; then
    [ $# -ge 1 -a "$1" = "-h" ] && do_usage=true && shift
    [ $# -ge 2 -a "$1" = "-F" -a "$2" != "" ] && { fname_opt="-F"; fname="$2"; shift 2; }
    if [ "$1" = "ERROR" -o "$1" = "WARN" -o "$1" = "INFO" -o "$1" = "DEBUG" -o "$1" = "TRACE" ]; then
        msg_level_str="${1}"
        msg_level_var="LOG_${1}"
        shift
    fi
    [ ${current_level} -lt ${!msg_level_var} ] && return 0
  fi

  _log_getfname $fname_opt $fname "$@" >/dev/null  # init env var storing logfile name (can't init in subprocess)

  $do_usage && printf "\nUsage: log {level} {message}\n  Log output to \"$log\"\n" 1>&2 && return 0

  # use awk to log via pipe (eg: echo 'some message' | log INFO), else use printf
  local fmt="[$(_log_stmp)|$msg_level_str|${FUNCNAME[1]}]"
  [ $# -eq 0 ] && awk -vfmt="$fmt" '{ printf fmt ": " $0 "\n" }' | _log_output $fname_opt $fname
  [ $# -gt 0 ] && printf -- "${fmt}: $@\n" | _log_output $fname_opt $fname
  return 0
}

# use this to determine if logging has already been configured
: ${HOMEDIR_BIN_COMMON_LOG_INIT:=1}

#########################################################################
# Either run as script, or just use functions by sourcing file (return true).
# If sourced, does NOT run 'log', otherwise it would block, waiting for stdin.
#
[ $# -gt 0 ] && log $@ || :

