#!/bin/bash
#
# Generic logging for scripts. Either call this script directly,
# or source this file to use the functions in another script.
#
# As a shell script:
#    log.sh [ERROR|INFO|DEBUG|TRACE] "message..."
#
# As a function:
#   log [ERROR|INFO|DEBUG|TRACE] "message..."
#   echo "message..." | log [ERROR|INFO|DEBUG|TRACE]
#
# To use the functions:
#   log() { :; }                   # no-op logger, in case log.sh not found
#   . $HOMEDIR_BIN/common/log.sh   # install this script somewhere
#   LOG_LEVEL=INFO                 # set level={NONE, ERROR, WARN, INFO, DEBUG}
#
# The following environment variables customize logging:
#   LOG_LEVEL={NONE|ERROR|WARN|INFO|DEBUG|TRACE}
#        Determine which log messages are logged. Default is INFO.
#
#   LOG={/path/to/logfile}
#        Set output log file. Default is /tmp/log_{user}_{script_name}.log
#
#   LOG_DIR=/tmp
#        Directory to write logfile to. Default is /tmp.
#
#   LOG_CONSOLE=1
#        Log to stderr, in addition to log file. Default is 0 (disabled).
#
#   LOG_MAX_SZ=1024
#        Size (in KB) to truncate log file. Default is 1024.
#

#########################################################################
# Note: if not using a known directory structure ($HOMEDIR_BIN):
#   PROG_PATH=${BASH_SOURCE[0]}   # get calling script's path
#   PROG_DIR=$(cd "$(dirname "${PROG_PATH:-$PWD}")" 2>/dev/null 1>&2 && pwd)
#   log() { :; }                  # no-op logger as fallback
#   . $PROG_DIR/../common/log.sh 2>/dev/null
#   LOG_LEVEL=INFO                # set level={NONE, ERROR, WARN, INFO, DEBUG}


#########################################################################
# global variables

: ${LOG_LEVEL:=INFO}     # clients set to: ERROR, WARN, INFO, DEBUG, TRACE (or NONE)
: ${LOG_MAX_SZ:=1024}    # logfile (approx) max size in KB
: ${LOG_CONSOLE:=0}      # set LOG_CONSOLE=1 to log to stderr
: ${LOG_TRUNC:=1}        # set LOG_TRUNC=0 to disable log truncation (or LOG_MAX_SZ=0)


#########################################################################
# standard format date, cross-platform test
#
if [ ${#LOG_USE_GNU_DATE} -eq 0 ]; then  # checking if set (not value)
  date --rfc-3339=seconds 2>/dev/null 1>&2 && export LOG_USE_GNU_DATE=1 || export LOG_USE_GNU_DATE=0
fi

_log_date() {
  [ ${LOG_USE_GNU_DATE:-0} -eq 1 ] && date --rfc-3339=seconds 2>/dev/null || date '+%Y-%m-%d %H:%M:%S%z'
  return 0
}

#########################################################################
# Return full path of script that sourced/called this script). Options:
#   -n   (default) return calling script name, as invoked (could be relative path)
#   -b   return only script name (i.e., basename)
#   -d   return the directory of calling script (i.e., dirname)
#   -s   return simplified / stripped version of script name (remove irregular chars)
#   -h   help/usage
#
_log_prog() {
  local prog=${BASH_SOURCE[${#BASH_SOURCE[@]}-1]}  # script that sourced/called this file
  local prog_name="${prog##*/}"                    # basename of script (strip path)
  [ $# -eq 0 ] && printf "$prog\n" && return 0

  while getopts bdnsh opt ; do
    case "$opt" in
      b) printf "${prog_name}\n"
         ;;
      d) printf "$(cd "$(dirname "$prog")" 2>/dev/null 1>&2 && pwd)\n"
         ;;
      n) printf "${prog}\n"
         ;;
      s) printf "${prog_name//[^a-zA-Z0-9_.]/-}\n"
         ;;
      h) printf "\n Usage: _log_prog [-n|-b|-d|-s]
         Pring program name, basename, dirname, etc. Options:
           -n  (default) script name, as invoked
           -b basename
           -d dirname
           -s stripped filename (basename) removing unusual/problematic characters.\n\n" 1>&2
         ;;
      *) log ERROR "** Error: unknown option given, args: $*"
         return 0  # should never get here (and returning false doesn't usually help)
         ;;
    esac
  done; shift $((OPTIND-1)); OPTIND=1
  return 0
}

#########################################################################
# Return output log filename, based on script name: "log_{user}_{script}.log"
# By default logs to /tmp, or if set use $LOG_DIR.  Options:
#   -d  {dir}  - use given directory for logfile.
#   -s         - use the calling script's directory for logfile.
# If "$LOG" is defined, simply return that as the fully qualified log filename.
#
_log_getfname() {
  [ "$LOG" != "" ] && printf "$LOG" && return 0
  local prog_pathN=$(_log_prog)        # original calling script name
  local prog_descN=$(_log_prog -s)     # simplfied version of filename
  #local prog_nameN=$(_log_prog -b)    # strip path (i.e,. basename)

  [ $# -gt 0 -a "$1" = "-s" ] && shift && LOG_DIR="$(_log_prog -d)"
  [ $# -gt 0 -a "$1" = "-d" -a -d "$1" ] && shift && LOG_DIR=$1
  LOG=${LOG_DIR:=/tmp}/log_${LOGNAME:-"$USER"}_${prog_descN}.log
  printf "[$(date)]==== Starting logging \"${prog_pathN}\" to: \"$LOG\"\n" >> $LOG
  printf "$LOG"
  return 0
}

#########################################################################
# Periodically truncate logfile (could rollover, etc.).
# Returns true (0) if truncated, false (non-zero) if not.
# Log truncation disabled if env var LOG_TRUNC=0 (by default it is enabled).
#
_log_check_truncate() {
  [ ${LOG_TRUNC:-1} -eq 0 -o ${LOG_MAX_SZ:-0} -le 0 ] && return 1
  [ "$LOG" = "" ] && LOG=$(_log_getfname)
  # notes:
  #  set SECONDS=0 after trunc would be better, but calling script may also use it
  #  sz=$(du -sk $LOG | cut -f1)  # => du/cut issue on z/OS
  local sz=0 cnt=$((SECONDS % 60))
  [ $cnt -lt 3 -a -f "$LOG" ] \
      && sz=$( expr "$(du -sk $LOG)" : '[^0-9]*\([0-9]*\)' ) \
      && ((sz > LOG_MAX_SZ)) \
      && cat /dev/null > $LOG \
      && printf "[$(date)][$FUNCNAME]: log truncated (size $sz KB > LOG_MAX_SZ=$LOG_MAX_SZ KB)\n" >> $LOG \
      && printf "[$(date)]==== Continue logging \"$(_log_prog)\" to: \"$LOG\"\n" >> $LOG \
      && return 0 \
      || return 1
}

#########################################################################
# Write output to $LOG, and also to stderr if LOG_CONSOLE=1
#
_log_output() {
  [ ${LOG_CONSOLE:-0} -eq 1 ] && tee -a $LOG | sed "s:^:\[$LOG\]:" 1>&2 || cat >> $LOG
  return 0
}


#########################################################################
# Log messages to log file with log level.
# Usage: log [ERROR|INFO|DEBUG|TRACE] "message..."
#   or:  echo "message..." | log [ERROR|INFO|DEBUG|TRACE]
#
# Writes to logfile only if the given {level} is greater than the
# current setting of $LOG_LEVEL. Logging defaults to "INFO".
# Valid levels are: NONE, ERROR, INFO, DEBUG, TRACE.
#
# If the log {level} is omitted, it defaults to "INFO".
# If the env var LOG_LEVEL is unset, it defaults to INFO.
# Setting LOG_LEVEL=NONE disables logging.
#
log() {
  # Strings mapped to log level numbers (prefixed w/ "LOG_" to avoid confusion)
  # (e.g., if foo="LOG_INFO", then ${!foo} == 2).  Default LOG_LEVEL="INFO"
  local LOG_NONE=0 LOG_ERROR=1 LOG_WARN=2 LOG_INFO=3 LOG_DEBUG=4 LOG_TRACE=5
  local msg_level_str="INFO" msg_level_var="LOG_INFO" current_level_var="LOG_${LOG_LEVEL}"
  local current_level=${!current_level_var}
  [ "$current_level" = "" ] && current_level=1

  if [ $# -gt 0 ]; then
    [ "$1" = "ERROR" -o "$1" = "WARN" -o "$1" = "INFO" -o "$1" = "DEBUG" -o "$1" = "TRACE" ] \
        && msg_level_str="${1}" \
        && msg_level_var="LOG_${1}" \
        && shift \
        && [ ${current_level} -lt ${!msg_level_var} ] \
        && return 0
  fi

  _log_check_truncate

  # use awk if logging via stdin (echo 'test' | log INFO), otherwise uses printf
  local fmt="[$(_log_date)|$msg_level_str|${FUNCNAME[1]}]"
  [ $# -eq 0 ] && awk -vfmt="$fmt" '{ printf fmt ": " $0 "\n" }' | _log_output
  [ $# -gt 0 ] && printf -- "${fmt}: $@\n" | _log_output
  return 0
}

HOMEDIR_BIN_COMMON_LOG_INIT=1

#########################################################################
# Either run as script, or just use functions by sourcing file (return true).
# If sourced, does NOT run 'log', otherwise, it blocks waiting for stdin.
#
[ $# -gt 0 ] && log $@ || :


