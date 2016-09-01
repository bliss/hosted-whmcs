#!/bin/bash

PHPINI=/etc/php/5.6/cli/php.ini
PHPFPMINI=/etc/php/5.6/fpm/php.ini
PHPVERSION=$(php --version | grep '^PHP' | sed 's/PHP \([0-9]\.[0-9]*\).*$/\1/')
ROOT=/var/opt/whmcs
NGINX_CONF=/etc/nginx/sites-enabled/default

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

test -e /whmcs*.zip && mv /whmcs*.zip /var/opt/persistent

WHMCS_ARCHIVE=$(ls /var/opt/persistent/whmcs*.zip 2>/dev/null)

VARS=/var/opt/persistent/vars.sh
test -e $VARS && rm -f $VARS
touch $VARS
chmod g-rwx,o-rwx $VARS
for var in WHMCS_DB_USER WHMCS_DB_HOST WHMCS_DB_NAME WHMCS_DB_PASSWORD WHMCS_LICENSE ADMIN_NAME ADMIN_FIRST_NAME ADMIN_LAST_NAME ADMIN_PASSWORD ADMIN_EMAIL;do
    if [[ ! -z ${!var} ]];then
        echo "$var=${!var}" >> $VARS
        unset $var
    fi
done

if [[ ! -z WHMCS_ARCHIVE ]];then
    WHMCS_ARCHIVE_RELEASE=$(echo $WHMCS_ARCHIVE | sed 's/.*whmcs[_-]\(.*\)\.zip/\1/')
    if [[ ! -e "$ROOT/.release" || $(cat $ROOT/.release) != $WHMCS_ARCHIVE_RELEASE ]]; then
        test -d $ROOT || mkdir $ROOT
        unzip -o $WHMCS_ARCHIVE -d $ROOT
        touch /var/opt/persistent/configuration.php
        chown www-data.www-data /var/opt/persistent/configuration.php
        test -e $ROOT/configuration.php || ln -s /var/opt/persistent/configuration.php $ROOT
        test -e /loghandler.php && mv /loghandler.php $ROOT/install
        chown -R www-data.www-data $ROOT
        rm -f $WHMCS_ARCHIVE
        rm -f /loghandler.php
    fi
fi

crontab -l | grep -q "php -q $ROOT/crons/cron.php" || echo "0 0  *  *  * php -q $ROOT/crons/cron.php" | crontab -

# Start supervisord and services
/usr/bin/supervisord -n -c /etc/supervisord.conf
