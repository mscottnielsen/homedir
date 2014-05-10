###############################################################################
# A cross-platform bash environment, customizable and extendable but also under
# version control; intended to be shared across hosts, OS's and even users.
#
# A single unversioned file "local.env" may be used for customization for the
# current user. All other config is under version control, loaded at login
# based on hostname, OS, username, and even for individual applications.
#
# If sh/csh/ksh is the default shell, then bash can be launched as a subshell
# (for those unfortunate situations (e.g., corp intranets) where the default
# shell isn't allowed to be changed.) The ".profile" just launches bash.
###############################################################################
#set -x
HOMEDIR_VER=920
HOMEDIR_LOG=$HOME/.h_log
#LOG_LEVEL=DEBUG
export HOMEDIR_VER HOMEDIR_LOG VERBOSE HOSTNAME PATH PS1 TR

h_tstamp() {
  local ts=$(date '+%s' 2>/dev/null)
  [ ${#ts} -lt 4 ] && ts=$(perl -e 'print time' 2>/dev/null)
  printf "$ts"
}

h_this=bashrc
ts_start=${ts_start0:-$(h_tstamp)}         # measure init time (from .profile, if set)
[ -f $HOME/.verbose_login ] && VERBOSE=1   # optional verbose logging
sh_type=$(echo "$0" | sed "s/^.*[-\/]//")  # get sh/ksh/bash not {-bash, /bin/bash,...}
: ${HOSTNAME:=$(hostname)}
h_tty="$(tty 2>/dev/null | grep -v 'not a')"
h_tty="tty${h_tty//[^0-9]/}"
h_log_prefix="[${HOSTNAME}][${h_tty}:$$][${sh_type}]"
h_log() {
  local pref
  if [ $# -gt 1 ]; then
    pref="$1 [${h_tty}:$$]"; shift
  else
    pref="[$(LC_TIME=C date)]${h_log_prefix}"
  fi
  printf "$pref (+$(($(h_tstamp) - ts_start))s) $*" >> $HOMEDIR_LOG
  return 0
}
export -f h_log
export -f h_tstamp

# avoid /etc/{profile,bashrc} if running remote ssh command, to avoid dynamic login menus
h_log "loading .${h_this} v=$HOMEDIR_VER, ${TERM}, BASH_SOURCE=${BASH_SOURCE},\$0=${0}, SHELL=${SHELL}\n"
[ ${sh_type} = "bash" -a "$TERM" != "dumb" -a "$TERM" != "" ] && [ -f /etc/${h_this} ] && . /etc/${h_this} >/dev/null 2>&1

if [ "$TR" = "" -a "$(uname)" = "SunOS" ]; then  # find working 'tr' (Solaris)
  [ "$TR" = "" -a -f /usr/xpg6/bin/tr ] && TR=/usr/xpg6/bin/tr
  [ "$TR" = "" -a -f /usr/xpg4/bin/tr ] && TR=/usr/xpg4/bin/tr
fi
: ${TR:="tr"}

PS1='\n\u@\h(\s[\l]) \w>\n\!$ '   # simple default, reset later


###############################################################################
# Set env vars w/ uniform cross-platform case & punctuation to identify platform:
# hostname (w/o domain); h_os={aix,hp-ux,linux,sunos}; h_arch={32, 64};
# h_arch_name={sparcv9, sparc, amd64, x86_64, 32, 64}. Only h_os_distro is free
# form, containing detailed distro info. See more examples in host*.env files.
#
export h_arch h_arch_name h_host h_os h_os_distro
: ${h_os:=$(expr "$(uname)" : '\([^._]*\)' | $TR '[:upper:]' '[:lower:]' | $TR '/' '_' | $TR -d ' ')}
: ${h_host:=$(expr "${HOSTNAME}" : '\([^.]*\)' | $TR '[:upper:]' '[:lower:]')}
: ${h_domain:=$(domainname 2>/dev/null | grep -v '(none)' | $TR '[:upper:]' '[:lower:]')}
: ${h_arch:=$( (isainfo -b|| getconf KERNEL_BITMODE|| getconf KERNEL_BITS|| getconf LONG_BIT|| echo "xx") 2>/dev/null)}
: ${h_arch_name:=$( (isainfo -n|| getconf KERNEL_BITMODE|| getconf KERNEL_BITS|| uname -m|| echo "xx") 2>/dev/null)}
: ${h_home_mnt:=$(df ~ 2>/dev/null |grep -v Filesystem |head -1 |awk -F: '{ print $1 }' |sed -e 's/^\/.*(//' -e 's/).*//' |awk '{print $1}')}

case "$h_os" in
  linux)  # eg, distro=RedHat_5 (not 5.4), EnterpriseServer_5/OracleServer_6 (not 6.2), Ubuntu_13 (not 13.04)
    : ${h_os_distro:="$(lsb_release -si|sed 's/ *//g; s/RedHat[A-Za-z]*/RedHat/; s/LINUX//g; s/EnterpriseEnterprise/Enterprise/g')_$(lsb_release -sr|cut -d. -f1)"}
    ;;
  sunos)  # eg, distro=SunOS_5.10
    : ${h_os_distro:="$(uname -s)_$(uname -r)"}
    ;;
  aix)    # eg, distro=AIX_6.1
    : ${h_os_distro:="$(uname -s)_$(uname -v).$(uname -r)"}
    ;;
  hp-ux)  # eg, distro=HP-UX_B.11.23, HP-UX_B.11.31
    : ${h_os_distro:="$(uname -s)_$(uname -r)"}
    h_arch_name=$(model | grep ia >/dev/null && echo ia || echo pa )
    ;;
  cygwin)
    h_arch_name=${PROCESSOR_ARCHITEW6432:-"$PROCESSOR_ARCHITECTURE"}
    [ "${h_arch_name##+([a-z])}" = "64" ] && h_arch=64 || h_arch=32
    ;;
  os_390) # eg, distro=zOS_1.13
    : ${h_os_distro:="$(uname -Is|sed 's/\///')_$(uname -Iv|sed 's/^0*//').$(uname -Ir|sed 's/\.0*$//')"}
    ;;
  *)
    : ${h_os_distro:="$h_os"}
    ;;
esac

###############################################################################
# terminal settings
#
term_verbose=0
case "$TERM" in
  vt* | ansi* | screen)
    [ "$TERM" = "screen" ] && TERM=vt100   # work-around for vi+screen
    # stty erase ''   # set erase char to delete (^?)
    stty erase ''     # or backspace (^H). ([cntrl-V] + [backspace or delete])
    stty -ixon          # disable xon/xoff (ctrl-s), so bash forward search works
    term_verbose=1
    ;;
  *cygwin*)
    # TERM=xterm        # for syntax hilite (vs. ansi or cygwin)
    stty erase ''
    stty -ixon
    term_verbose=1
    ;;
  dumb)                  # for scp, sftp
    ;;
  dtterm)
    stty erase ''
    stty -ixon
    term_verbose=1
    ;;
  xterm*)
    stty erase ''
    stty -ixon
    test -n "$DISPLAY" && ( type xset && xset b 0 ) > /dev/null 2>&1
    term_verbose=1
    ;;
  *)
    # stty erase ''
    ;;
esac

# until here, .profile & .bashrc are (intentionally) nearly identical
#  * .profile => check if not bash, and launch bash subshell
#  * .bashrc => load per-user and per-os/host env settings

###############################################################################
# Config is in $HOMEDIR, default relative to (real) .bashrc, else assume $HOME
#
export HOMEDIR HOMEDIR_ENV
[ "${BASH_SOURCE[0]}" != "" ] && HOMEDIR="$(dirname -- ${BASH_SOURCE[0]})" || HOMEDIR="$(dirname -- ${0})"
[ ${#HOMEDIR} -le 2 ] || [ "$(dirname $HOMEDIR)" = "/" ] && HOMEDIR="$HOME"

export HOMEDIR HOMEDIR_BIN HOMEDIR_ENV HOMEDIR_USER_ENV HOMEDIR_HOST_ENV USER_ORG

[ -e $HOME/local.env ] && h_log "  " "loading local.env" && source $HOME/local.env && h_log " " "done.\n"
: ${HOMEDIR_ENV:="$HOMEDIR/env"}
[ -f $HOMEDIR_ENV/setup.env ] && source $HOMEDIR_ENV/setup.env

h_log "loaded .${h_this} v=$HOMEDIR_VER - done\n\n"

