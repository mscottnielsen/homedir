#!/bin/bash

# Print how much memory a process is using. 
# By default, Pss (propportioinal set size), Rss adjusted for sharing,
# Could also do Rss (resident).


get_pid() {
  ps -F -C "$1" | awk '{print $2 }' | grep -v PID | head -1
}

proc=firefox
measure=Pss

[ $# -gt 0 ] && proc=$1 && shift

while true; do
  ps -F -C $proc 
  pid=$(get_pid $proc)
  [ -f /proc/$pid/smaps ] \
      && usage=$(echo 0 $(cat /proc/$pid/smaps \
            | grep "$measure" \
            | awk '{print $2}' \
            | sed 's#^#+#') \
            | bc) \
      && echo "===$usage ($(echo "$usage/1024" | bc )M)"
  sleep 0.5s 
done | uniq

