#!/bin/bash

perl=perl5.8
script=/usr/local/nde/ade/util/adhoc_query_scripts/list_merges_to_branch.pl
branch=main
product=OGG
days=10
limit=OGGADP
OPTIND=1

while getopts b:d:hp: opt
do
  case "$opt" in
  b) branch=${OPTARG};;
  d) days=${OPTARG};;
  p) product=${OPTARG};;
  h) printf "\n Usage: $0 [-b {branch}] [-d {days}] [-p {product}] [filter]\n\n";
     exit 2;
     ;;
  *) echo "** unknown option" ; exit 2 ;;
  esac
done; shift $((OPTIND-1)); OPTIND=1

[ $# -gt 0 ] && limit="$@"

do_filter() {
  egrep "$limit"
}

ade exec $perl $script -b $branch -p $product -d $days  -no_files  |  do_filter


