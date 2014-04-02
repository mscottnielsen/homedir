#!/bin/bash
##
## Logging functions for shell scripts, intended to be 'sourced'
## from other scripts (but can be run as script, too).
##
## Env vars:
##    LOG_FILE the logfile filename (default=output*.log)
##    LOG_DIR  the output directory (default=/tmp).
## To set the log level to 'error' (default) 'info', 'debug' or 'trace', set:
## LOG_LEVEL={NONE,ERROR,WARN,INFO,DEBUG,TRACE} -- e.g,
## LOG_LEVEL=INFO
##
##


###############################################################################
# from calling script, set LOG_LEVEL (default=INFO) to the string (not 
# the variable, not the number); INFO, WARN or ERROR (or NONE ).  For debug
# logging, use DEBUG or TRACE.

LOG_LEVEL=${LOG_LEVEL:-INFO}
#LOG_LEVEL=DEBUG

# map log levels to strings, "INFO" = 3, "DEBUG" = 4, etc.
LOG_NONE=0; LOG_ERROR=1; LOG_WARN=2; LOG_INFO=3; LOG_DEBUG=4; LOG_TRACE=5

###############################################################################
# set "run" to disable (but do log) certain actions written as: run cmd [...]
run=
#run=_no_op
_no_op() {
  log INFO "[run-disabled] $*"
}

###############################################################################
# script path, filename, directory
PROG_PATH=${BASH_SOURCE[0]}      # this script's name
PROG_NAME=${PROG_PATH##*/}       # basename of script (strip path)
PROG_DIR="$(cd "$(dirname "${PROG_PATH:-$PWD}")" 2>/dev/null 1>&2 && pwd)"

# calling script (if this script is sourced)
PROG_PATH_1=${BASH_SOURCE[${#BASH_SOURCE[@]}-1]}  # calling script that sourced/called this script
PROG_NAME_1="${PROG_PATH_1##*/}"
PROG_DIR_1="$(cd "$(dirname "${PROG_PATH_1:-$PWD}")" 2>/dev/null 1>&2 && pwd)"

###############################################################################
# Output dir and filename can be set separately with LOG_DIR and LOG_FILE.
# These can be overridden by just setting LOG={/path/to/file.log}
[ "$LOG_FILE" = "" ] && LOG_FILE="log_${LOGNAME:-$USER}_$(basename $PROG_NAME_1 .sh)${run}.log"
[ "$LOG" = "" ] && LOG=${LOG_DIR:="/tmp"}/${LOG_FILE}

#################################################################################
# TMPFILE=${TMPFILE:="/tmp/tmp.$0.$$"}
#
# # trap on error
# # cleanup tmp files on exit. On any error, trap and exit, then cleanup
# trap 'echo "cleaning up tmp files... $(test -f "$TMPFILE" && rm -f "${TMPFILE}" || log DEBUG "no tmpfile created")" >/dev/null 2>&1' 0
# trap "exit 2" 1 2 3 15
#

###############################################################################
# function log {level} [msg...]
# Pass in the log level as: INFO, DEBUG, VERBOSE, ...
# The current setting of the env varLOG_LEVEL determines if the msg is printed
# to the logfile or not.
#
# Usage: log [ERROR|WARN|INFO|DEBUG|TRACE] "message"
#    or: echo "message" | log [ERROR|WARN|INFO|DEBUG|TRACE]
#
log() {
  # set to {LOG_INFO, LOG_DEBUG,...}, which is the variable name
  local log_level_varname=LOG_${LOG_LEVEL}
  local level="INFO" log_level="LOG_${level}" current=${!log_level_varname}
  [ "$current" = "" ] && current=${LOG_ERROR}

  [ $# -gt 0 ] \
     && [ "$1" = "ERROR" -o "$1" = "WARN" -o "$1" = "INFO" -o "$1" = "DEBUG" -o "$1" = "TRACE" ] \
     && level="${1}" && log_level="LOG_${1}" && shift \
     && [ ${current} -lt ${!log_level} ] \
     && return 0

  local prefx="** [$(date)] [${level}]"
  [ $# -eq 0 ] && awk -vprefx="$prefx" -vargs="$*" '{ printf prefx ": " args " " $0 "\n" }'  | tee -a $LOG
  [ $# -gt 0 ] && printf -- "${prefx}: $@\n" | tee -a $LOG
  return 0
}


#

# ------------------------------------------------------------------------
# Modelines: {{{1
# vim:ts=8 fdm=marker

