#!/bin/bash

PDIR=/var/opt/persistent
CONF=$PDIR/configuration.php

test -d $PDIR || exit 1
test -e $CONF || exit 1

DUMP=$1

if [ -z "$DUMP" ];then
    echo "Usage: $0 /path/to/dump"
    exit 0
fi

if [ ! -e "$DUMP" ];then
    echo "ERROR: $DUMP not found"
    exit 1
fi

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

FORMAT=$(file -bi $DUMP)
echo $FORMAT | grep -q "application/zip"
if [ $? -eq 0 ];then
    unzip -p $DUMP | mysql -u $db_username -p$db_password -h $db_host $db_name
    exit 0
fi
echo $FORMAT | grep -q "application/gzip"
if [ $? -eq 0 ];then
    zcat $DUMP | mysql -u $db_username -p$db_password -h $db_host $db_name
    exit 0
fi
echo $FORMAT | grep -q "text/plain"
if [ $? -eq 0 ];then
    mysql -u $db_username -p$db_password -h $db_host $db_name < $DUMP
    exit 0
fi
echo "Unsupported format: $FORMAT; zip, gzip and plain text are supported only."
exit 0