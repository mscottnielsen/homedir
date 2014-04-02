#!/bin/bash
#
# Test if oracle is up and running.
#

ORA_USER=${ORA_USER:-"$USER"}
ORA_PASS=${ORA_PASS:-"$USER"}
MAILTO=${MAILTO:-"$USER"@"$HOSTNAME"}
TMPFILE=/tmp/check_$ORACLE_SID.ora

#***********************************************************
# Test to see if Oracle is running
check_stat=$( ps -ef|grep ${ORACLE_SID}|grep pmon|wc -l)
oracle_num=`expr $check_stat`

# echo ================
# echo "check_stat: $check_stat / oracle_num: $oracle_num"
# echo ================
 
printf "Oracle (SID=$ORACLE_SID) "

if [ $oracle_num -lt 1 ]; then
  printf "is **NOT** running. "
else
  printf "is running. "
fi



#***********************************************************
# Test to see if Oracle is accepting connections
$ORACLE_HOME/bin/sqlplus -S $ORA_USER/$ORA_PASS <<EOF > $TMPFILE
  select * from v\$database;
exit
EOF

check_stat=`cat $TMPFILE | grep -i error | wc -l`;
oracle_num=`expr $check_stat`
if [ $oracle_num -ne 0 ]
then
  # mailx -s "Oracle ORACLE_SID=$ORACLE_SID is down!" $MAILTO
  printf "Oracle is **NOT** accepting connections.\n"
  egrep -i 'error|^ora-' $TMPFILE | egrep -v '^ERROR:'
  echo ============
  env | grep ORA
  echo ============
else
  printf "Oracle is accepting connections. \n"
fi

#echo ========= $TMPFILE ======
#debug_do=cat
#debug_do=ls
#[ -f $TMPFILE ] && $debug_do $TMPFILE
[ -f $TMPFILE ] && rm $TMPFILE


