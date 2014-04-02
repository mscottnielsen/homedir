#!/bin/bash
#
# Set DESKTOP_SESSION, guessing which desktop is running (gnome, mate, kde,...)[1]
# Either source this file to set the env var, *or* eval the output of results.
#   $   . desktop_session.sh            #  export DESKTOP_SESSION=gnome
#   $   eval $( desktop_session.sh -p )
# Optionally use "-u" to unset DESKTOP_SESSION_ID, if causing problems [2]
#
# [1] https://netbeans.org/bugzilla/show_bug.cgi?id=227754
# [2] http://wiki.netbeans.org/FaqCplusPlusRemoteSocketException


PROG_PATH=${BASH_SOURCE[0]}      # this script's name
PROG_NAME=${PROG_PATH##*/}       # basename of script (strip path)
#PROG_DIR="$(cd "$(dirname "${PROG_PATH:-$PWD}")" 2>/dev/null 1>&2 && pwd)"

desktop_session_help() { cat<<EOF_HELP 1>&2

  Usage: $PROG_NAME [ -u | -p | -v | -h ] [{default_desktop_session}]
    Set env var DESKTOP_SESSION, attempting to guess which desktop
    is actually running {gnome, cinnamon, mate, kde,...}.  To run,
    either source this file, e.g.:
       .  \$( $PROG_NAME  )
    or generate script commands, and evaluate the output, e.g.,
       eval \$( $PROG_NAME -p )

  Options:
    -h    print this help message
    -p    print commands to execute, to pass to eval
    -q    quiet (disable verbose / debug output)
    -u    unset DESKTOP_SESSION_ID env vars
    -v    verbose/debug output, printed to stderr

EOF_HELP
}

desktop_session_print() {
    local default_session=gnome
    [ $# -gt 0 ] && default_session=$1 && shift

    log() {
        $verbose && echo "# $@" 1>&2
        return 0
    }

    search_env() {
        # search env for any var named "{mate,gnome,cinnamon,...}_DESKTOP.*"
        env | egrep -qi "^${1}_DESKTOP" 1>&2
    }

    search_proc() {
        ps -A | grep -v grep | egrep -q "${1}"
    }

    if [ "$DESKTOP_SESSION" != "" ] ; then
        # use existing DESKTOP_SESSION, if it does NOT contain "default"
        if ! echo "$DESKTOP_SESSION" | egrep -qi 'default' ; then
            log "using predefined, non-default DESKTOP_SESSION=$DESKTOP_SESSION"
            echo "$DESKTOP_SESSION"
            return 0
        fi
    fi

    for s in mate cinnamon lxde xfce jwm gnome kde ; do
        # guess session from env vars & processes (precedence matters)
        if search_env "$s" ; then
            log "assume $s desktop (found ${s}_desktop env var)"
            echo "$s"
            return 0
        fi
        if search_proc " ${s}-" ; then
            log "looking for ${s}: found process \"${s}-*\""
            echo "$s"
            return 0
        fi
    done

    if [ "$DESKTOP_SESSION" != "" ] ; then
        # if set, go ahead and allow DESKTOP_SESSION=default
        log "using existing desktop session: \"${DESKTOP_SESSION}\""
        echo "$DESKTOP_SESSION"
        return 0
    fi

    # only if DESKTOP_SESSION can't be determined and is unset (returns false)
    log "using default desktop session: $default_session"
    echo "$default_session"

    return 1
}

desktop_session_id_unset() {
    for x in $( env | grep _DESKTOP_SESSION_ID | cut -d= -f1 ) ; do
        $verbose && echo "# unset env var: $x" 1>&2
        unset $x
        $print_cmds && echo unset $x
    done
}



desktop_session_main() {
    local opt OPTIND OPTARG
    local verbose=false do_unset=false print_cmds=false ret=0 session=

    while getopts hpquv opt ; do
        case "$opt" in
          h) desktop_session_help
             return 1
             ;;
          p) print_cmds=true
             ;;
          u) do_unset=true
             ;;
          v) verbose=true
             ;;
          q) verbose=false
             ;;
          *) printf "# ** error: unknown option ($@)\n" 1>&2
             desktop_session_help
             return 1  #  if sourced, don't exit
             ;;
        esac
    done; shift $((OPTIND-1)); OPTIND=1

    session=$(desktop_session_print $@)
    ret=$?
    export DESKTOP_SESSION=$session
    $print_cmds && echo "export DESKTOP_SESSION=$session"
    $do_unset && desktop_session_id_unset
    return $ret
}

desktop_session_main $@

