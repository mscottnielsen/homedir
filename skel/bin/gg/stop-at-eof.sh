#!/bin/bash
############################################################################
# ggsci loop, testing 'lag' on a process. When at EOF, stop
# the process, and the loop exits.
#
# By default, continues to loop until the process is started.
#
# Usage: stop-at-eof.sh [-s {seconds}]  [process]
#   [process]     - the extract or replicat name (default: javaue)
#   -s {seconds}  - seconds to sleep before checking lag (default: 2)
############################################################################

. ${HOMEDIR_ENV:-"$HOME/env"}/app-goldengate.env

# ggsci output: print status & continue
tst_cont="Last record|LAG|not currently"

# print status & stop
tst_stop="Invalid|At EOF|No ER groups"

pause=2

[ $# -gt 0 -a "$1" = "-s" ] && pause=$2 && shift 2
[ $# -gt 0 ] && proc=$1 || proc=javaue

while true; do
  tee >(grep .  >&2) < <(gg lag er $proc | egrep "$tst_cont|$tst_stop" && printf '(waiting...)' ) | egrep "$tst_stop" && { gg stop ${proc}; break; }
  sleep $pause
done


