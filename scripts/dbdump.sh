#!/bin/bash

PDIR=/var/opt/persistent
CONF=$PDIR/configuration.php
DDIR=$PDIR/hosted-dumps

test -d $PDIR || exit 1
test -e $CONF || exit 1
test -d $DDIR || mkdir $DDIR


while read LINE;do
    echo $LINE | grep -q ^\$db || continue
    VAR=$(echo ${LINE%%=*}|tr -d '$ ')
    VALUE=$(echo ${LINE#*=}|sed "s/\(^'\|';$\)//g")
    printf -v $VAR $VALUE
done < $CONF

for var in db_username db_name db_host db_password;do
    if [ -z "${!var}" ];then
        echo "$var is empty"
        exit 1
    fi
done

exec mysqldump --opt -u $db_username -p$db_password -h $db_host $db_name | gzip > $DDIR/dump_$(date +%Y%m%d_%H%M%S).sql.gz