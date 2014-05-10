#!/bin/bash
prog=${BASH_SOURCE[0]##*/}
usage() { cat<<USAGE_EOF

   Run a single command on a list of remote hosts.

   Usage:
    run-remote-cmd.sh [-h] "{command} [options ...]" host1 [host2 ...]

   Options:
      -h  print usage

   To set the list of hosts, either set the env var RMT_HOSTS or give the
   hosts after the command.

   To interupt the currently executing remote call, type "control+C", or
   send SIGTERM to the script (e.g., kill {pid}). The script will continue
   to run, processing the remaining hosts.

   To interupt the script and NOT continue to run with the remaining hosts, either:
      * press "ctrl+c" two (or more) times in a row, OR
      * send SIGUSR1 to the process:  e.g., kill -s USR1 {pid}

   Examples:
    Using an env var for remote hosts:
      \$ RMT_HOSTS="host1 host2 host3"  $prog  "free -m"
      \$ RMT_HOSTS="host1,host2,host3"  $prog  "java -version"

    Give hosts as args, optionally running more than one command,
      \$ $prog   cmd "host1,host2,host3"
      \$ $prog  "cmd1 -option; cmd2"  host1 host2 host3

   Notes:
     The following is basically done to run the remote command, with some
     special logic to handle interupts:
       \$ ssh hostname bash -c 'some_command'

USAGE_EOF
 return 0
}

#RMT_HOSTS=${RMT_HOSTS:-"kabuki sfo-sun-01 omnibus bandi aixvm-03"}
RMT_HOSTS=${RMT_HOSTS:-"localhost"}

# temp file, file name parameterized, accessed via getTmp function
tmpfile=/tmp/run_cmd.$$.tmpfile.%s.txt

[ "$VERBOSE" = "true" -o "$VERBOSE" = "1" ] && verbose=true || verbose=false
current_host=""

err_count=0
ok_count=0
quiet=false



################################################################
## (start counters) unfortuantely, variables aren't able to be
## set and used together with traps. So persisiting variables
## to tmp files seems the only way to keep track of number of interupts
################################################################

# get and init the tmpfile
#
getTmp() {
  [ $# -eq 0 ] && f=$(printf "$tmpfile" 0) || f=$(printf "${tmpfile}" $1)
  [ ! -e $f ] && printf "0\n" > $f
  echo "$f"
}

# storing counters in tmpfiles: getting the value
#
getCount() {
  cat $(getTmp $@)
}

# delete tmp file
#
cleanTmp() {
  f=$(getTmp $@)
  [ -e $f ] && { rm -f $f || printf "warning: unable to remove tempfile: $f\n" ; }
}

# Storing counters in tmpfiles: set and/or increment.
# Usage: updateCount {counter} [value]
#   increment by 1 (default); or if value given, set to given value.
#   if value arg is given, counter_name must come first.
#   if value is 0, counter is reset to 0.
updateCount() {
  local quiet=false
  [ $# -gt 0 -a "$1" = "-q" ] && quite=true
  local f=$(getTmp $@)
  local cnt=$(cat $f)
  local val=1
  [ $# -gt 0 ] && shift
  [ $# -gt 0 ] && val="${1}" && cnt=0
  $quiet &&  printf "$((cnt + val))\n" > tee  $f \
         ||  printf "$((cnt + val))\n" | tee  $f
  return 0
}
############################## end counter stuff

ok() {
  printf "\n\n===done (success / $(( ok_count  = ok_count + 1 )) ) ===\n\n" > /dev/null
}

not_ok() {
  printf "\n\n===done (error / $(( err_count = err_count + 1 )) ) ===\n\n" > /dev/null
}

signal_recv() {
  sig_count=$(updateCount sig)
  tot_count=$(updateCount tot)

  echo "...interrupt received (sig_count=$sig_count, consecutive=$tot_count)" 1>&2
  [ "$sig_count" -gt 1 ] && [ "$tot_count" -gt 1 ] && echo "...exiting (intrp=$tot_count)" 1>&2 && exit 2

  echo "...continuing. To terminate, interupt again (immediately), or send:  kill -s USR1 $$" 1>&2
  return 0
}

cleanup() {
 cleanTmp tot
 cleanTmp sig
 return 0
}

run_rmt_cmd() {
  local ssh_opt='StrictHostKeyChecking no'
  #local ssh_cmd='ssh -Y -o'
  local ssh_cmd="ssh -x -o"
  local cmd="$@"

  if $verbose ; then
    echo "==============================="
    echo "Run command: \"$cmd\""
    echo "On hosts:    $RMT_HOSTS"
    echo
  fi

  for rmthost in $RMT_HOSTS
  do
    sleep 2  # give chance for second interupt
    tot_count=$(updateCount tot 0)  # reset counter
    sig_count=$(getCount sig)

    current_host=$rmthost
    printf "\n======== $rmthost ==========  ($$) (stats: interupts=$sig_count (consecutive: $tot_count), errs=$err_count, success=$ok_count)\n"
    $ssh_cmd "$ssh_opt" "$rmthost" bash -c \'${cmd}\' && ok || not_ok
    echo
  done
}


## cleanup on interruption and exit... but instead of exiting,
## just keep running until finished with all hosts.
## Send sigusr1 (16) to terminate everything.

trap 'printf "\n...cleaning up...\n" && cleanup && printf "\n...done\n"' 2>&1 0
trap 'cleanup && printf "\n"' 2>&1 0
trap signal_recv SIGHUP SIGINT SIGQUIT SIGPIPE SIGTERM
trap "exit 2" SIGUSR1

# $ /bin/kill -L
#  1 HUP      2 INT      3 QUIT     4 ILL      5 TRAP     6 ABRT     7 BUS
#  8 FPE      9 KILL    10 USR1    11 SEGV    12 USR2    13 PIPE    14 ALRM
# 15 TERM    16 STKFLT  17 CHLD    18 CONT    19 STOP    20 TSTP    21 TTIN
# 22 TTOU    23 URG     24 XCPU    25 XFSZ    26 VTALRM  27 PROF    28 WINCH
# 29 POLL    30 PWR     31 SYS

###################################
# run remote command
###################################

[ $# -eq 0 -o $# -gt 0 -a "$1" = "-h" ] && usage && exit 2
[ $# -gt 0 -a "$1" = "-q" ] && verbose=false && shift

#cmd="free -m"
cmd="java -version"

[ $# -ge 1 ] && cmd="$1" && shift
[ $# -ge 1 ] && RMT_HOSTS="$@"

RMT_HOSTS=$(echo "$RMT_HOSTS" | sed "s/, */ /g")
run_rmt_cmd "$cmd"


