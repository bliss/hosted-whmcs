#!/bin/bash

PHPINI=/etc/php/5.6/cli/php.ini
PHPFPMINI=/etc/php/5.6/fpm/php.ini
PHPVERSION=$(php --version | grep '^PHP' | sed 's/PHP \([0-9]\.[0-9]*\).*$/\1/')
ROOT=/var/opt/whmcs
NGINX_CONF=/etc/nginx/sites-enabled/default
WHMCSCONF=/var/opt/persistent/configuration.php
# Display PHP error's or not
if [[ "$ERRORS" == "true" ]] ; then
  sed -i -e "s/error_reporting\s*=.*/error_reporting = E_ALL/" \
    -e "s/display_errors\s*=.*/display_errors = On/" $PHPINI
fi

# Create path for PHP sessions
mkdir -p -m 0777 /var/lib/php5

# Set PHP timezone
if [ -z "$PHPTZ" ]; then
  PHPTZ="Europe/London"
fi
echo date.timezone = $PHPTZ >>$PHPINI

# Tweak nginx to match the workers to cpu's
CPUS=$(grep -c processor /proc/cpuinfo)
sed -i -e "s/worker_processes\s\S*/worker_processes $CPUS;/" /etc/nginx/nginx.conf

if [ ! -z "$SERVER_NAME" ];then
    grep -q server_name $NGINX_CONF || sed -i -e "/root\s\+\/var\/opt\/whmcs/a \\\tserver_name $SERVER_NAME;" $NGINX_CONF
fi

test -d /run/php || mkdir -p /run/php
if [ ! -d /usr/local/ioncube ];then
    mkdir /usr/local/ioncube
    cp /tmp/ioncube/ioncube_loader_lin_$PHPVERSION.so /usr/local/ioncube
fi
grep -q "zend_extension = /usr/local/ioncube/ioncube_loader_lin_$PHPVERSION.so" $PHPFPMINI \
  || echo zend_extension = /usr/local/ioncube/ioncube_loader_lin_$PHPVERSION.so >>$PHPFPMINI

grep -q "zend_extension = /usr/local/ioncube/ioncube_loader_lin_$PHPVERSION.so" $PHPINI \
  || echo zend_extension = /usr/local/ioncube/ioncube_loader_lin_$PHPVERSION.so >>$PHPINI

test -e /whmcs*.zip && mv /whmcs*.zip /var/opt/persistent

WHMCS_ARCHIVE=$(ls /var/opt/persistent/whmcs*.zip 2>/dev/null)

VARS=/var/opt/persistent/vars.sh
for var in DB_USERNAME DB_HOST DB_NAME DB_PASSWORD LICENSE TEMPLATES_COMPILEDIR;do
    if [[ ! -z ${!var} ]];then
        lcvar=$(echo "$var" | tr '[:upper:]' '[:lower:]')
        echo "\$$lcvar = '${!var}';" >> $VARS
        unset $var
    fi
done

if [[ ! -z WHMCS_ARCHIVE ]];then
    WHMCS_ARCHIVE_RELEASE=$(echo $WHMCS_ARCHIVE | sed 's/.*whmcs[_-]\(.*\)\.zip/\1/')
    if [[ ! -e "$ROOT/.release" || $(cat $ROOT/.release) != $WHMCS_ARCHIVE_RELEASE ]]; then
        test -d $ROOT || mkdir $ROOT
        unzip -o $WHMCS_ARCHIVE -d $ROOT
        if [[ ! -d $ROOT/install && -d $ROOT/whmcs ]];then
            mv $ROOT/whmcs/* $ROOT
            rm -rf $ROOT/whmcs
        fi
        if [[ ! -e $WHMCSCONF ]];then
            echo "<?php" >> $WHMCSCONF
            cat $VARS >> $WHMCSCONF
            EHASH=$(date +%s | sha256sum | base64 | head -c 63)
            echo "\$cc_encryption_hash = '$EHASH';" >> $WHMCSCONF
            grep -q templates_compiledir $WHMCSCONF || echo "\$templates_compiledir = 'templates_c';" >> $WHMCSCONF
            echo "\$mysql_charset = 'utf8';" >> $WHMCSCONF
            chown www-data.www-data $WHMCSCONF
            test -e $ROOT/configuration.php || ln -s $WHMCSCONF $ROOT
            cd $ROOT
            COUNTER=1
            while [[ $COUNTER -le 20 ]];do
                echo "Attempt $COUNTER to deploy"
                php install/bin/installer.php --install --non-interactive 2>&1 | tee $ROOT/install/deploy.log
                grep -qi "^\(username\|password\)" $ROOT/install/deploy.log && break
                COUNTER=$(( COUNTER+1 ))
                sleep 15
            done
            cat $ROOT/install/deploy.log | grep -i "^\(username\|password\)" > /var/opt/persistent/credentials
        fi
        chown www-data.www-data $WHMCSCONF
        test -e $ROOT/configuration.php || ln -s $WHMCSCONF $ROOT
        test -e /loghandler.php && mv /loghandler.php $ROOT/install
        chown -R www-data.www-data $ROOT
        rm -f $WHMCS_ARCHIVE
        rm -f /loghandler.php
    fi
fi

test -e $VARS && rm -f $VARS
#rm -rf $ROOT/install

crontab -l | grep -q "php -q $ROOT/crons/cron.php" || echo "0 0  *  *  * php -q $ROOT/crons/cron.php" | crontab -

# Start supervisord and services
/usr/bin/supervisord -n -c /etc/supervisord.conf
