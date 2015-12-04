#!/bin/sh

########################################################################
#
# Jeedom installer: shell script to deploy Jeedom and its dependencies
#
########################################################################

############################ Translations ##############################
# MUST be embedded, otherwise the network installation of Jeedom
# won't work!


install_msg_en() {
    msg_installer_welcome="*      Welcome to the Jeedom installer/updater        *"
    msg_nginx_config="*                  NGINX configuration                 *"
    msg_yes="yes"
    msg_no="no"
    msg_yesno="yes/no: "
    msg_cancel_install="Canceling the installation"
    msg_answer_yesno="Answer yes or no"
    msg_install_deps="*               Dependencies installation              *"
    msg_passwd_mysql="What password do you have just typed (MySQL root password)?"
    msg_confirm_passwd_mysql="Do you confirm that the password is:"
    msg_bad_passwd_mysql="The MySQL password provided is invalid!"
    msg_setup_dirs_and_privs="*      Creating directories and setting up rights      *"
    msg_copy_jeedom_files="*                Copying files of Jeedom               *"
    msg_unable_to_download_file="Unable to download the file"
    msg_config_db="*               Configuring the database               *"
    msg_install_jeedom="*                 Installing de Jeedom                 *"
    msg_update_jeedom="*                  Updating de Jeedom                  *"
    msg_setup_cron="*                   Setting up cron                    *"
    msg_setup_cron="*                   Setting up nginx                   *"
    msg_post_install_actions="*             Post-installation actions                *"
    msg_post_update_actions="*               Post-update actions                    *"
    msg_install_complete="*                Installation complete                 *"
    msg_update_complete="*                   Update complete                    *"
    msg_or="or"
    msg_login_info1="You can log in to Jeedom by going on:"
    msg_login_info2="Your credentials are:"
    msg_php_version="PHP version found : "
    msg_php_already_optimized="PHP is already optimized, using : "
    msg_uptodate="is already installed and up-to-date"
    msg_needinstallupdate="needs to be installed or to be updated"
}

##################### Main (script entry point) ########################

# Select the right language, among available ones
install_msg_en

echo "********************************************************"
echo "${msg_installer_welcome}"
echo "********************************************************"

# Check for root priviledges
if [ $(id -u) != 0 ] ; then
    echo "Super-user (root) privileges are required to install Jeedom"
    echo "Please run 'sudo $0' or log in as root, and rerun $0"
    exit 1
fi

webserver_home="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "********************************************************"
echo "${msg_config_db}"
echo "********************************************************"

MYSQL_HOST=localhost
MYSQL_PORT=3306
MYSQL_JEEDOM_USER=jeedom
MYSQL_JEEDOM_DBNAME=jeedom
echo "mysql-server mysql-server/root_password password root" | debconf-set-selections
echo "mysql-server mysql-server/root_password_again password root" | debconf-set-selections
apt-get -y install mysql-client
apt-get -y install mysql-common
apt-get -y install mysql-server
bdd_root_password=$(cat /dev/urandom | tr -cd 'a-f0-9' | head -c 15)
mysqladmin -u root password ${bdd_root_password}
bdd_password=$(cat /dev/urandom | tr -cd 'a-f0-9' | head -c 15)
echo "DROP USER '${MYSQL_JEEDOM_USER}'@'%'" | mysql -uroot -p${bdd_root_password}
echo "CREATE USER '${MYSQL_JEEDOM_USER}'@'%' IDENTIFIED BY '${bdd_password}';" | mysql -uroot -p${bdd_root_password}
echo "DROP DATABASE IF EXISTS ${MYSQL_JEEDOM_DBNAME};" | mysql -uroot -p${bdd_root_password}
echo "CREATE DATABASE ${MYSQL_JEEDOM_DBNAME};" | mysql -uroot -p${bdd_root_password}
echo "GRANT ALL PRIVILEGES ON ${MYSQL_JEEDOM_DBNAME}.* TO '${MYSQL_JEEDOM_USER}'@'%';" | mysql -uroot -p${bdd_root_password}

cp core/config/common.config.sample.php core/config/common.config.php
sed -i -e "s/#PASSWORD#/${bdd_password}/g" core/config/common.config.php 
sed -i -e "s/#DBNAME#/${MYSQL_JEEDOM_DBNAME}/g" core/config/common.config.php 
sed -i -e "s/#USERNAME#/${MYSQL_JEEDOM_USER}/g" core/config/common.config.php 
sed -i -e "s/#PORT#/${MYSQL_PORT}/g" core/config/common.config.php 
sed -i -e "s/#HOST#/${MYSQL_HOST}/g" core/config/common.config.php 
chown www-data:www-data core/config/common.config.php

echo "********************************************************"
echo "${msg_install_deps}"
echo "********************************************************"

apt-get update
apt-get -y install nginx-common nginx-full ca-certificates libudev1 unzip curl
apt-get -y install build-essential
apt-get -y install libarchive-dev
apt-get -y install libpcre3-dev
apt-get -y install libssh2-php
apt-get -y install libtinyxml-dev libxml2 libjsoncpp-dev
apt-get -y install make ntp usb-modeswitch python-serial
apt-get -y install php5-cli php5-common php5-curl php5-dev php5-fpm php5-json php5-mysql php5-ldap php5-memcached php5-redis php-pear
apt-get autoremove

echo "********************************************************"
echo "${msg_setup_dirs_and_privs}"
echo "********************************************************"

cd ${webserver_home}
chown www-data:www-data -R ${webserver_home}

echo "********************************************************"
echo "${msg_copy_jeedom_files}"
echo "********************************************************"

mkdir ${webserver_home}/jeedom/tmp
chmod 775 -R ${webserver_home}
chown -R www-data:www-data ${webserver_home}
cd ${webserver_home}/jeedom

echo "********************************************************"
echo "${msg_install_jeedom}"
echo "********************************************************"

php install/install.php mode=force

echo "********************************************************"
echo "${msg_setup_cron}"
echo "********************************************************"

JEEDOM_CRON="`crontab -l | grep -e 'jeeCron.php'`"

if [ -z "${JEEDOM_CRON}" ] ; then
    croncmd="su --shell=/bin/bash - www-data -c '/usr/bin/php ${webserver_home}/jeedom/core/php/jeeCron.php' >> /dev/null 2>&1"
    cronjob="* * * * * $croncmd"
    ( crontab -l | grep -v "$croncmd" ; echo "$cronjob" ) | crontab -
fi

echo "www-data ALL=(ALL) NOPASSWD: ALL" | (EDITOR="tee -a" visudo)

echo "********************************************************"
echo "${msg_nginx_config}"
echo "********************************************************"
for i in apache2 apache ; do
    if [ -f "/etc/init.d/${i}" ] ; then
        service ${i} stop
        update-rc.d -f ${i} remove
    fi
done
service nginx stop
cp install/nginx_default /etc/nginx/sites-available/default
if [ ! -f '/etc/nginx/sites-enabled/default' ] ; then
    ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default
fi
service nginx restart
update-rc.d nginx defaults  

echo "********************************************************"
echo "${msg_post_install_actions}"
echo "********************************************************"

service php5-fpm restart
sed -i 's/max_execution_time = 30/max_execution_time = 300/g' /etc/php5/fpm/php.ini
sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 1G/g' /etc/php5/fpm/php.ini
sed -i 's/post_max_size = 8M/post_max_size = 1G/g' /etc/php5/fpm/php.ini
sed -i 's/expose_php = On/expose_php = Off/g' /etc/php5/fpm/php.ini

echo "********************************************************"
echo "${msg_install_complete}"
echo "********************************************************"
IP=$(ifconfig eth0 | grep 'inet addr:' | cut -d: -f2 | awk '{print $1}')
HOST=$(hostname -f)
echo "${msg_login_info1}"
echo "\n\t\thttp://$IP/jeedom ${msg_or} http://$HOST/jeedom\n"
echo "${msg_login_info2} admin/admin"
