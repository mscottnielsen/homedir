#!/bin/bash
#
# Stripped-down example of a ggsci wrapper.  Either run as script, or just
# use function 'gg' by sourcing the file. If sourced, it does NOT run 'gg'.
#
#  Usage:
#   $ gg.sh info all
#   $ gg.sh  # does nothing
#  or:
#   $ . gg.sh
#   $ gg info all
#   $ gg  # interactive ggsci
#

_gg_sh_printenv() {
  type ${PAGER:="less"} >/dev/null 2>&1 \
    || { type less >/dev/null 2>&1 && PAGER=less ; } \
    || { type more >/dev/null 2>&1 && PAGER=more ; } \
    || { type cat >/dev/null 2>&1 && PAGER=cat ; }

  [ "$PAGER" = "less" -a "$LESS" = "" ] && LESS="-ReXF"

  : ${GGSCI:="./ggsci"}                        # path to ggsci (assume ".")
  : ${GGSCI_EDITOR:="${EDITOR:-"vim"}"}        # non-GUI editor for ggsci
  : ${GGSCI_VISUAL:="${VISUAL:-"gvim"}"}       # GUI editor for ggsci
  : ${GGSCI_PAGER:="${PAGER}"}                 # use "less" (default) or "more"
  : ${RLWRAP:="rlwrap"}                        # rlwrap (found in PATH); only
  type $RLWRAP >/dev/null 2>&1 || RLWRAP=      #   use rlwrap if found

  echo "export GGSCI=\"${GGSCI}\"; "
  echo "export RLWRAP=\"${RLWRAP}\"; "
  echo "export GGSCI_EDITOR=\"${GGSCI_EDITOR}\"; "
  echo "export GGSCI_PAGER=\"${GGSCI_PAGER}\"; "
  echo "export PAGER=\"${PAGER}\"; "
  [ "$PAGER" = "less" -o "$GGSCI_PAGER" = "less" ] && echo "export LESS=\"${LESS}\"; "
  echo "export _GG_SH_PRINTENV=1"
}

#############################################################################
# Run ggsci or logdump inside rlwrap (if installed). If a file is given as
# an arg, assume logdump is to be run; otherwise run ggsci.
#
gg() {
  # condense ggsci output (use awk to avoid sed limitations on solaris)
  local ggsci_to_ignore=$($GGSCI -v | tr -d '\r' | sed "s/[^A-Za-z0-9]/./g" | awk 'BEGIN{printf "^Copyright "} /./{printf "|^ *%s",$0;next}')
  local pager=$GGSCI_PAGER

  bangify() {
    # add "!" after any "stop manager" command (simple sed)
    sed 's/\([Ss][Tt][Oo][Pp]  *[Mm].*[Gg].*[Rr]\) *!*$/\1!/'
    return 0
  }

  if [ $# -eq 0 ]; then
    [ "$RLWRAP" != "" ] && printf "** run: $RLWRAP $GGSCI\n"
    $RLWRAP $GGSCI
  else
    echo "$@" | grep -i "^ *view " >/dev/null || pager=cat  # page (more/less) only for "view"
    if echo "$@" | grep -i "^ *edit " >/dev/null ; then     # if "edit", don't invoke ggsci
      $GGSCI_EDITOR "$@"
    else
      # Run any ggsci command, strip ggsci banner and everything up to first non-blank line.
      printf "$*\n" | bangify | $GGSCI | egrep -v "$ggsci_to_ignore" |  sed -n '/^[^ ]/,$p' | $pager
    fi
  fi
}

[ ${_GG_SH_PRINTENV:-0} -eq 0 ] && eval $( _gg_sh_printenv )

[ $# -gt 0 ] && gg "$@" || :

