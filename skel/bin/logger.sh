#!/bin/bash
##
## Logging for scripts; optionally 'source' this file directly to
## use the "log" function directly. Env vars:
##    LOG_FILE  - log filename (default: log_{user}_{calling_script}.log)
##    LOG_DIR   - output directory (default=/tmp).
##    LOG_LEVEL - log level, set to  {NONE,ERROR,WARN,INFO,DEBUG,TRACE} 
##                e.g., export LOG_LEVEL=INFO
##    LOG  - override LOG_FILE and LOG_DIR; instead log to the given
##           full path to a logfile
##
## Usage (change "log" to "log.sh" to use as script):
##    export LOG_LEVEL=INFO
##    log INFO "this will be logged"
##    log WARN "so will this"
##    log DEBUG "this will NOT be logged"
##


###############################################################################
# From calling script, set LOG_LEVEL (default=INFO) to INFO, WARN, ERROR, NONE.
# For debug logging, use DEBUG or TRACE. For example, to enable WARN and ERROR
# but disable INFO and DEBUG messages: export LOG_LEVEL=WARN

export LOG_LEVEL
: ${LOG_LEVEL:=INFO}

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
# Script path, filename, directory. If option "-b", return basename w/o suffix.
_calling_script() {
  #PROG_PATH=${BASH_SOURCE[0]}      # this script's name
  #PROG_NAME=${PROG_PATH##*/}       # basename of script (strip path)
  #PROG_DIR="$(cd "$(dirname "${PROG_PATH:-$PWD}")" 2>/dev/null 1>&2 && pwd)"

  # calling script (if this script is sourced)
  local prog_path_1=${BASH_SOURCE[${#BASH_SOURCE[@]}-1]}  # calling script that sourced/called this script
  local prog_name_1="${prog_path_1##*/}"
  #local prog_dir_1="$(cd "$(dirname "${prog_path_1:-$PWD}")" 2>/dev/null 1>&2 && pwd)"

  # without suffix ".sh"
  local prog_base_1=${prog_name_1%.*}

  [ $# -gt 0 -a "$1" = "-b" ] && printf "$prog_base_1" || return "$prog_name_1"
  return 0
}


###############################################################################
# Output dir and filename can be set separately with LOG_DIR and LOG_FILE.
# These can be overridden by just setting LOG={/path/to/file.log}
[ "$LOG_FILE" = "" ] && LOG_FILE="log_${LOGNAME:-$USER}_$(_calling_script -b)${run}.log"
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
# Pass in the log level as: {INFO, DEBUG, VERBOSE, ...}. The current setting of
# the env var LOG_LEVEL determines if the msg is printed to the logfile or not. 
# Usage: log {level} "message"
#   or: echo "message" | log {level}
#   {level} is one of: {NONE,ERROR,WARN,INFO,DEBUG,TRACE}
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

# ------------------------------------------------------------------------
# Modelines: {{{1
# vim:ts=8 fdm=marker

