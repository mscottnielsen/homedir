#!/bin/bash
#
# Print or set network proxy: both env vars and gnome (gsettings) network
# proxy to manual, none (or 'auto'). Set env vars by 'sourcing' script.
#
# Pass the proxy host as a command-line arg, or use the meta env var H_PROXY_HOST
#
# Sets both upper & lowercase vars (some utils prefer one xor the other): eg, for curl/wget/git:
#   export http_proxy="www-proxy.mycompany.com:80"
#   export https_proxy="www-proxy.mycompany.com:80"
#   export ftp_proxy="www-proxy.mycompany.com:80"
#   export all_proxy="www-proxy.mycompany.com:80"
#
# ...but 'links', & some windows ports of the GNU utils use:
#   export HTTP_PROXY="$http_proxy"
#   export HTTPS_PROXY="$https_proxy"
#   export FTP_PROXY="$ftp_proxy"
#

h_proxy_set_verbose=false
type gsettings > /dev/null 2>&1 && use_gsettings=true || use_gsettings=false

proxy_script_default() {
    local proxy=http://www-proxy
    local domain=$(hostname -d)
    [ "$domain" != "" ] && proxy=${proxy}.${domain}:80
    echo "$proxy"
}

: ${H_PROXY_HOST:=$(proxy_script_default)}

###########################################################################
# script name (keeping exposed variables to a minimum)
proxy_script_basename() {
  basename ${BASH_SOURCE[0]##*/}
}

###########################################################################
# print help to stderr
proxy_do_help() { cat<<EOF 1>&2
 Usage: $(proxy_script_basename) [-m {mode}] [-s|-p|-u] {url}
 Must 'source' script to set or unset env vars; e.g.:  source $(proxy_script_basename) -u
 Options:
   -m {mode}  set proxy to use named proxy preset: e.g., manual (default) or auto
   -p    print current proxy env settings (before setting/unsetting)
   -s    set proxy (this is the default)
   -u    unset proxy: unset env vars, set proxy preset to 'none'
EOF
  return 0
}

###########################################################################
# convert argument to uppercase
proxy_to_upper() {
  echo "$@" | tr '[a-z]' '[A-Z]' # old bash (3.2) doesn't work: upper_x=${x^^}
}

###########################################################################
# if the script is run (not sourced), issue warning
proxy_do_warn_source() {
  echo "$0" | grep "set_proxy" > /dev/null && cat<<EOF 1>&2
## **NOTE: 'source' script to update proxy env vars: \$ source $(proxy_script_basename)
EOF
  return 0
}

###########################################################################
# unset variables, for eval
proxy_do_unset_var() {
  local v1=$1
  local v2=$(proxy_to_upper "$1")

  $h_proxy_set_verbose && printf "# unsetting: ${v1}=\"${!v1}\", ${v2}=\"${!v2}\"\n" 1>&2
  $h_proxy_set_verbose && printf "unset ${v1};\n" 1>&2
  $h_proxy_set_verbose && printf "unset ${v2};\n" 1>&2

  printf "unset ${v1};\n"
  printf "unset ${v2};\n"
}

###########################################################################
# echo "export var=value" suitable as input for 'eval'
# usage: var value
#  prints export var=value; export VAR=value
proxy_do_set_var() {
  local v1=$1
  local v2=$(proxy_to_upper "$1")
  local url=$2

  $h_proxy_set_verbose && printf "# setting: ${v1}=${v2}=${url}\n" 1>&2
  $h_proxy_set_verbose && printf "export ${v1}=\"${url}\";\n" 1>&2
  $h_proxy_set_verbose && printf "export ${v2}=\"${url}\";\n" 1>&2

  printf "export ${v1}=\"${url}\";\n"
  printf "export ${v2}=\"${url}\";\n"
}

###########################################################################
# print "echo value=variable" suitable as input for 'eval'
proxy_do_print_var() {
  local v1=$1 v2=$(proxy_to_upper "$1")
  printf "echo \'${v1}=\"${!v1}\"\';\n"
  printf "echo \'${v2}=\"${!v2}\"\';\n"
}

###########################################################################
# invoke gsettings for proxy (if gsettings exists)
proxy_do_print_gsettings() {
  $use_gsettings && printf "# $@ org.gnome.system.proxy mode=$(gsettings get org.gnome.system.proxy mode)\n" 1>&2
  return 0
}

###########################################################################
proxy_do_set_gsettings() {
  local m=$default_proxy_mode
  [ $# -gt 0 ] && m=$1

  if $use_gsettings
  then
    $h_proxy_set_verbose && proxy_do_print_gsettings "current:"
    #echo gsettings set org.gnome.system.proxy mode ${m} 1>&2
    gsettings set org.gnome.system.proxy mode ${m}
    $h_proxy_set_verbose && proxy_do_print_gsettings "updated:"
  else
    $h_proxy_set_verbose && printf "(gsettings not installed.)"
  fi

  return 0
}

###########################################################################
# set/unset proxy. generates output to be executed by 'eval'.
# Iterates over proxy env vars to set/unset, upper and lowercase.
# If both printing & updating the proxy, prints existing value, before update.
do_proxy() {
  local opt OPTIND OPTARG
  local proxy_set=false
  local proxy_unset=false
  local proxy_print=false
  local proxy_mode=manual
  local proxy_url="http://www-proxy.mycompany.com:80"  #  some utils complain if no preceeding "http://"
  proxy_vars=( http_proxy https_proxy ftp_proxy all_proxy )

  [ $# -eq 0 ] && proxy_set=true

  while getopts hm:psu  opt; do
    case "$opt" in
      u) proxy_mode=none
         proxy_unset=true
         ;;
      m) proxy_mode=${OPTARG}  # use given proxy mode
         proxy_set=true
         ;;
      p) proxy_print=true
         ;;
      s) proxy_set=true    # (default) set proxy 'manual'
         ;;
      h) proxy_do_help     # print help & return;
         return 1          # can't exit if sourced
         ;;
      q) h_proxy_set_verbose=false
         ;;
      *) printf "# ** error: unknown option ($@)\n" 1>&2
         ;;
    esac
  done; shift $((OPTIND-1)); OPTIND=1

  [ $# -gt 0 ] && { proxy_url=$1 ; shift; } || proxy_url=${H_PROXY_HOST}

  $proxy_print && proxy_do_print_gsettings

  if $proxy_set || $proxy_unset ; then
    proxy_do_set_gsettings $proxy_mode 1>&2
    proxy_do_warn_source # sourcing required for env vars (not gsettings)
 fi

  for v in ${proxy_vars[*]} ; do
    $proxy_print && proxy_do_print_var $v
    $proxy_unset && proxy_do_unset_var $v
    $proxy_set   && proxy_do_set_var   $v $proxy_url
  done
  return 0
}

###########################################################################
# do_proxy generates commands to execute; eg, 'export foo=value' or 'unset foo'
# All other output is printed to stderr.

eval $( do_proxy "$@" )

