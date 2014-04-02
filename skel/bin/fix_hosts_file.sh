#!/bin/bash

###########################################################################
# Reformat hosts file so that 127.0.0.1 is  at the top, mapped to `hostname`.
# Otherwise, certain apps hang when attempting to communicate to localhost
# after connecting to a vpn, since NetworkManager prepends "ip hostname" to
# the *top* of the file, above the 127.0.0.1/hostname line.
#
# In short, this may have to be called every time after connecting to the VPN.
# Therefore, this script also sets the proxy by default as well.
###########################################################################

tmp_h=/tmp/etc_hosts
backup=/tmp/etc_hosts.backup
log=/tmp/tmp_fix_hosts_file.${LOGNAME}.log
host=$(hostname)
ret=1



trap 'echo "cleaning up tmpfiles..." >/dev/null && rm -f $tmp_h >/dev/null 2>&1' 0
trap "exit 2" 1 2 3 15


###########################################################################
print_usage() {
  printf "
  Usage: $0 [-B | -L | -P ]
     -B  disable backup of hosts file
     -L  disable writing to log file
     -P  disable set proxy
     -p  {name} set proxy to given predefined setting (default=$use_proxy)\n"
  return 0
}

###########################################################################
# debug logging only
log(){
  $do_log || return 0
  ts() { date  '+%F %R'; return 0; }
  echo "==[${FUNCNAME[1]}] $(ts) ($(whoami) : $(tty))==  $* " | sed 's/\\n/\n/g' >> $log
  return 0
}

###########################################################################
# get just 127.0.0.1 entry from /etc/hosts, append hostname
get_localhost() {
  egrep    '^127.0.0.1' /etc/hosts  | sed "s/^127.0.*/&  $host/"
}

# get everything *except* 127.0.0.1 from /etc/hosts
get_hostsfile() {
  egrep -v '^127.0.0.1' /etc/hosts
}

# (debug) get localhost setting from the given file, print to logfile
print_localhost() {
  local tmpf=$1
  log "...verify contents: $(file ${tmpf} 2>&1)"
  [ -f "$tmpf" ] && log "$tmpf: \n$(egrep "^::|127|$host|^[0-9]" $tmpf 2>&1)"
}

###########################################################################
set_proxy() {
  gsettings set org.gnome.system.proxy mode "$1" 2>&1
  log "updated proxy settings: $(gsettings get org.gnome.system.proxy mode 2>&1)"
}


###########################################################################
# main
###########################################################################

do_backup=true      # create a backup of /etc/hosts in /tmp
do_log=true         # writing debug msgs logfile, $log
do_proxy=true       # do set proxy after updating /etc/hosts
use_proxy=manual    # proxy predefined setting
OPTIND=1

while getopts BhLPp: opt; do
  case "$opt" in
    B) do_backup=false ;;
    L) do_log=false ;;
    P) do_proxy=false ;;
    p) use_proxy=${OPTARG};;
    *|h) print_usage; exit 1 ;;
  esac
done ; shift $((OPTIND-1)); OPTIND=1

$do_backup && cp /etc/hosts $backup && print_localhost $backup
cat <(get_localhost) <(get_hostsfile) > $tmp_h
[ -f $tmp_h ] && gksudo -k cp $tmp_h /etc/hosts && ret=0
print_localhost /etc/hosts
$do_proxy && set_proxy $use_proxy

exit $ret

