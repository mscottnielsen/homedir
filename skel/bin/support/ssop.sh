#!/bin/bash

enc=$HOME/.pw.enc

usage() { cat<<EOF
  ${BASH_SOURCE[0]##*/} [-f encrypted_file] [get|put]
     Either get or put encrypted text from file, by default, "$enc" 
     Interactively asks for both passphrase to encrypt text,
     and the text to be encrypted.
EOF
  return 0
}

# encrypt_pass:
#    foo=passphrase
#    openssl des3 -in <(echo testpw) -out file.enc -pass env:foo
#
# decrypt_pass:
#    openssl des3 -d -in $enc
#
# options:
#    openssl des3 -in <(echo test) -out $enc -pass file:${pw_file}
#    openssl des3 -in <(echo test) -out $enc -pass env:pw
#    openssl des3 -in <(echo test) -out $enc -pass env:${pw_var}


remove_old_file() {
  [ ! -f "$1" ] && return 0
  rm -i "$1"
  [ -f "$1" ] &&  { printf "** warning: file exists: $1\n"; return 1 ; }
  return 0
}

masked_read() {
  # not secure, since user can see var being set
  local pass char prompt="Enter text to encrypt: "
  [ $# -gt 0 ] && prompt=$1
  while IFS= read -p "$prompt" -r -s -n 1 char
  do
     [ "$char" = $'\0' ] && break
     prompt='*'
     pass="${pass}${char}"
   done 1>&2
   echo "$pass"
}


do_crypt() {
  local do_get=true do_put=false
  local pw
  if [ $# -gt 0 ]; then
    [ "$1" = "-f" ] && enc=$2 && shift 2
    [ "${1:0:1}" = "-" ] && { usage; return 2; }
    [ "$1" = "get" ] && do_get=true
    [ "$1" = "put" ] && do_put=true
  fi
  
  if $do_put ; then
    remove_old_file $enc || {  printf "** error: encrypted file exists: $enc\n"; return 2; }
    pw=$(masked_read "Enter text to encrypt: " ) && echo || { printf "\n** error: unable to read text to encrypt\n"; return 2; }
    openssl des3 -in <(echo $pw) -out $enc
  elif $do_get ; then
    [ ! -f "$enc"  ] && { printf "** error: file does not exist: $enc\n"; return 2; }
    openssl des3 -d -in $enc
  fi
}

do_crypt "$@"

