#!/bin/sh
VERT="\\033[1;32m"
NORMAL="\\033[0;39m"
ROUGE="\\033[1;31m"
ROSE="\\033[1;35m"
BLEU="\\033[1;34m"
BLANC="\\033[0;02m"
BLANCLAIR="\\033[1;08m"
JAUNE="\\033[1;33m"
CYAN="\\033[1;36m"

if [ $(id -u) != 0 ] ; then
    echo "Super-user (root) privileges are required to install Jeedom"
    echo "Please run 'sudo $0' or log in as root, and rerun $0"
    exit 1
fi

apt_install() {
  apt-get -y install "$@"
  if [ $? -ne 0 ]; then
	echo "${ROUGE}Could not install $@ - abort${NORMAL}"
	exit 1
  fi
}

mysql_sql() {
  echo "$@" | mysql -uroot -proot
  if [ $? -ne 0 ]; then
    echo "C${ROUGE}ould not execute $@ into mysql - abort${NORMAL}"
    exit 1
  fi
}

step_1_upgrade() {
	echo "---------------------------------------------------------------------"
	echo "${JAUNE}Start step_1_upgrade${NORMAL}"
	apt-get update
	apt-get -y dist-upgrade
	apt-get -f install
	apt-get update
	apt-get -y dist-upgrade
	apt-get -f install
	echo "${VERT}step_1_upgrade success${NORMAL}"
}

step_2_mainpackage() {
	echo "---------------------------------------------------------------------"
	echo "${JAUNE}Start step_2_mainpackage${NORMAL}"
	apt_install ntp ca-certificates unzip curl sudo cron
	apt-get -y install smbclient htop iotop vim iftop
	echo "${VERT}step_2_mainpackage success${NORMAL}"
}

step_3_database() {
	echo "---------------------------------------------------------------------"
	echo "${JAUNE}Start step_3_database${NORMAL}"
	echo "mysql-server mysql-server/root_password password root" | debconf-set-selections
	echo "mysql-server mysql-server/root_password_again password root" | debconf-set-selections
	apt_install mysql-client mysql-common mysql-server
	
	mysqladmin -u root password root
	
	systemctl status mysql > /dev/null 2>&1
	if [ $? -ne 0 ]; then
    	service mysql status
		if [ $? -ne 0 ]; then
    		systemctl start mysql > /dev/null 2>&1
    		if [ $? -ne 0 ]; then
				service mysql start > /dev/null 2>&1
			fi
  		fi
  	fi
  	systemctl status mysql > /dev/null 2>&1
	if [ $? -ne 0 ]; then
    	service mysql status
		if [ $? -ne 0 ]; then
    		echo "${ROUGE}Could not start mysql - abort${NORMAL}"
    		exit 1
  		fi
  	fi
	echo "${VERT}step_3_database success${NORMAL}"
}

step_4_apache() {
	echo "---------------------------------------------------------------------"
	echo "${JAUNE}Start step_4_apache${NORMAL}"
	apt_install apache2 apache2-utils libexpat1 ssl-cert
	echo "${VERT}step_4_apache success${NORMAL}"
}

step_5_php() {
	echo "---------------------------------------------------------------------"
	echo "${JAUNE}Start step_5_php${NORMAL}"
	apt-get -y install php7.0 php7.0-curl php7.0-gd php7.0-imap php7.0-json php7.0-mcrypt php7.0-mysql php7.0-opcache php7.0-xmlrpc libapache2-mod-php7.0 php7.0-common php7.0-dev php7.0-zip php7.0-ssh2
	if [ $? -ne 0 ]; then
		apt_install libapache2-mod-php5 php5 php5-common php5-curl php5-dev php5-gd php5-json php5-memcached php5-mysql php5-cli php5-ssh2
	fi
	echo "${VERT}step_5_php success${NORMAL}"
}

step_6_jeedom_download() {
	echo "---------------------------------------------------------------------"
	echo "${JAUNE}Start step_6_jeedom_download${NORMAL}"
	wget https://github.com/jeedom/core/archive/${VERSION}.zip -O /tmp/jeedom.zip
	if [ $? -ne 0 ]; then
		echo "${JAUNE}Could not download jeedom from github, use preadd version if exist${NORMAL}"
		if [ -f /root/jeedom.zip ]; then
			cp /root/jeedom.zip /tmp/jeedom.zip
		fi
	fi
	if [ ! /tmp/jeedom.zip ]; then
		echo "${ROUGE}Could not retrieve jeedom.zip package - abort${NORMAL}"
    	exit 1
	fi
	mkdir -p ${WEBSERVER_HOME}
	find ${WEBSERVER_HOME} ! -name 'index.html' -type f -exec rm -rf {} +
	rm -rf /root/core-*
	unzip -q /tmp/jeedom.zip -d /root/
	if [ $? -ne 0 ]; then
    	echo "${ROUGE}Could not unzip archive - abort${NORMAL}"
    	exit 1
  	fi
	cp -R /root/core-*/* ${WEBSERVER_HOME}
	rm -rf /root/core-* > /dev/null 2>&1
	rm /tmp/jeedom.zip
	echo "${VERT}step_6_jeedom_download success${NORMAL}"
}

step_7_jeedom_customization() {
	echo "---------------------------------------------------------------------"
	echo "${JAUNE}Start step_7_jeedom_customization${NORMAL}"
	cp ${WEBSERVER_HOME}/install/apache_security /etc/apache2/conf-available/security.conf
	rm /etc/apache2/conf-enabled/security.conf > /dev/null 2>&1
	ln -s /etc/apache2/conf-available/security.conf /etc/apache2/conf-enabled/
	rm /etc/apache2/conf-available/other-vhosts-access-log.conf > /dev/null 2>&1
	rm /etc/apache2/conf-enabled/other-vhosts-access-log.conf > /dev/null 2>&1
	for file in ` find / -name php.ini -type f`;do
		echo "Update php file ${file}"
		sed -i 's/max_execution_time = 30/max_execution_time = 300/g' ${file} > /dev/null 2>&1
	    sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 1G/g' ${file} > /dev/null 2>&1
	    sed -i 's/post_max_size = 8M/post_max_size = 1G/g' ${file} > /dev/null 2>&1
	    sed -i 's/expose_php = On/expose_php = Off/g' ${file} > /dev/null 2>&1
	done
	
	systemctl restart apache2 > /dev/null 2>&1
	if [ $? -ne 0 ]; then
		service apache2 restart
		if [ $? -ne 0 ]; then
    		echo "${ROUGE}Could not restart apache - abort${NORMAL}"
    		exit 1
  		fi
  	fi
	echo "${VERT}step_7_jeedom_customization success${NORMAL}"
}

step_8_jeedom_configuration() {
	echo "---------------------------------------------------------------------"
	echo "${JAUNE}Start step_8_jeedom_configuration${NORMAL}"
	echo "DROP USER 'jeedom'@'%';" | mysql -uroot -proot > /dev/null 2>&1
	mysql_sql "CREATE USER 'jeedom'@'%' IDENTIFIED BY 'jeedom';"
	mysql_sql "DROP DATABASE IF EXISTS jeedom;"
	mysql_sql "CREATE DATABASE jeedom;"
	mysql_sql "GRANT ALL PRIVILEGES ON jeedom.* TO 'jeedom'@'%';"
	cp ${WEBSERVER_HOME}/core/config/common.config.sample.php ${WEBSERVER_HOME}/core/config/common.config.php
	sed -i "s/#PASSWORD#/jeedom/g" ${WEBSERVER_HOME}/core/config/common.config.php 
	sed -i "s/#DBNAME#/jeedom/g" ${WEBSERVER_HOME}/core/config/common.config.php 
	sed -i "s/#USERNAME#/jeedom/g" ${WEBSERVER_HOME}/core/config/common.config.php 
	sed -i "s/#PORT#/3306/g" ${WEBSERVER_HOME}/core/config/common.config.php 
	sed -i "s/#HOST#/localhost/g" ${WEBSERVER_HOME}/core/config/common.config.php 
	chmod 775 -R ${WEBSERVER_HOME}
	chown -R www-data:www-data ${WEBSERVER_HOME}
	echo "${VERT}step_8_jeedom_configuration success${NORMAL}"
}

step_9_jeedom_installation() {
	echo "---------------------------------------------------------------------"
	echo "${JAUNE}Start step_9_jeedom_installation${NORMAL}"
	php ${WEBSERVER_HOME}/install/install.php mode=force
	if [ $? -ne 0 ]; then
    	echo "${ROUGE}Could not install jeedom - abort${NORMAL}"
    	exit 1
  	fi
	echo "${VERT}step_9_jeedom_installation success${NORMAL}"
}

step_10_jeedom_crontab() {
	echo "---------------------------------------------------------------------"
	echo "${JAUNE}Start step_10_jeedom_crontab${NORMAL}"
	if [ $(crontab -l | grep ${WEBSERVER_HOME}/core/php/jeeCron.php | wc -l) -eq 0 ];then
		(echo "* * * * * su --shell=/bin/bash - www-data -c '/usr/bin/php ${WEBSERVER_HOME}/core/php/jeeCron.php' >> /dev/null"; crontab -l | grep -v "jeedom" | grep -v "jeeCron") | crontab -
		if [ $? -ne 0 ]; then
	    	echo "${ROUGE}Could not install jeedom cron - abort${NORMAL}"
	    	exit 1
	  	fi
  	fi
	echo "${VERT}step_10_jeedom_crontab success${NORMAL}"
}

step_11_jeedom_sudo() {
	echo "---------------------------------------------------------------------"
	echo "${JAUNE}Start step_11_jeedom_sudo${NORMAL}"
	usermod -a -G dialout,tty www-data
	if [ $(grep "www-data ALL=(ALL) NOPASSWD: ALL" /etc/sudoers | wc -l) -eq 0 ];then
		echo "www-data ALL=(ALL) NOPASSWD: ALL" | (EDITOR="tee -a" visudo)
		if [ $? -ne 0 ]; then
    		echo "${ROUGE}Could not install make jeedom sudo - abort${NORMAL}"
    		exit 1
  		fi
  	fi
	echo "${VERT}step_11_jeedom_sudo success${NORMAL}"
}

step_12_jeedom_check() {
	echo "---------------------------------------------------------------------"
	echo "${JAUNE}Start step_12_jeedom_check${NORMAL}"
	php ${WEBSERVER_HOME}/sick.php
	if [ $? -ne 0 ]; then
    	echo "${ROUGE}Could not install make jeedom sudo - abort${NORMAL}"
    	exit 1
  	fi
	echo "${VERT}step_12_jeedom_check success${NORMAL}"
}

addon_1_openzwave(){
	echo "---------------------------------------------------------------------"
	echo "${JAUNE}Start addon_1_openzwave${NORMAL}"
	wget https://raw.githubusercontent.com/jeedom/plugin-openzwave/master/resources/install.sh -O /tmp/openzwave_install.sh
	if [ $? -ne 0 ]; then
		echo "${ROUGE}Could not install openzwave dependancy - abort${NORMAL}"
    	exit 1
	fi
	chmod +x /tmp/openzwave_install.sh
	/tmp/openzwave_install.sh
	if [ $? -ne 0 ]; then
    	echo "${ROUGE}Could not install openzwave dependancy - abort${NORMAL}"
    	exit 1
  	fi
}

distrib_1_spe(){
	if [ -f /etc/armbian.txt ]; then
		wget https://raw.githubusercontent.com/jeedom/core/beta/install/OS_specific/armbian/post-install.sh
		chmod +x post-install.sh
		./post-install.sh
		rm post-install.sh
	fi
}

STEP=0
VERSION=stable
WEBSERVER_HOME=/var/www/html
INSTALL_ZWAVE_DEP=0
HTML_OUTPUT=0

while getopts ":s:v:w:z:h:" opt; do
  case $opt in
    s) STEP="$OPTARG"
    ;;
    v) VERSION="$OPTARG"
    ;;
    w) WEBSERVER_HOME="$OPTARG"
    ;;
    z) INSTALL_ZWAVE_DEP=1
    ;;
    h) HTML_OUTPUT=1
    ;;
    \?) echo "${ROUGE}Invalid option -$OPTARG${NORMAL}" >&2
    ;;
  esac
done

if [ ${HTML_OUTPUT} -eq 1 ]; then
	VERT="</pre><span style='color:green;font-weight: bold;'>"
	NORMAL="</span><pre>"
	ROUGE="<span style='color:red;font-weight: bold;'>"
	ROSE="<span style='color:pink;font-weight: bold;'>"
	BLEU="<span style='color:blue;font-weight: bold;'>"
	BLANC="<span style='color:white;font-weight: bold;'>"
	BLANCLAIR="<span style='color:blue;font-weight: bold;'>"
	JAUNE="<span style='color:#FFBF00;font-weight: bold;'>"
	CYAN="<span style='color:blue;font-weight: bold;'>"
	echo "<script>"
	echo "setTimeout(function(){ window.scrollTo(0,document.body.scrollHeight); }, 100);"
	echo "setTimeout(function(){ window.scrollTo(0,document.body.scrollHeight); }, 300);"
	echo "setTimeout(function(){ location.reload(); }, 1000);"
	echo "</script>"
	echo "<pre>"
fi

echo "${JAUNE}Welcome to jeedom installer${NORMAL}"
echo "${JAUNE}Jeedom install version : ${VERSION}${NORMAL}"
echo "${JAUNE}Webserver home folder : ${WEBSERVER_HOME}${NORMAL}"
if [ ${INSTALL_ZWAVE_DEP} -eq 1 ]; then
	echo "${JAUNE}With openzwave${NORMAL}"
fi

case ${STEP} in
   0)
	echo "${JAUNE}Start of all install step${NORMAL}"
	step_1_upgrade
	step_2_mainpackage
	step_3_database
	step_4_apache
	step_5_php
	step_6_jeedom_download
	step_7_jeedom_customization
	step_8_jeedom_configuration
	step_9_jeedom_installation
	step_10_jeedom_crontab
	step_11_jeedom_sudo
	step_12_jeedom_check
	distrib_1_spe
	;;
   1) step_1_upgrade
	;;
   2) step_2_mainpackage
	;;
   3) step_3_database
	;;
   4) step_4_apache
	;;
   5) step_5_php
	;;
   6) step_6_jeedom_download
	;;
   7) step_7_jeedom_customization
	;;
   8) step_8_jeedom_configuration
	;;
   9) step_9_jeedom_installation
	;;
   10) step_10_jeedom_crontab
	;;
   11) step_11_jeedom_sudo
	;;
   12) step_12_jeedom_check
	;;
   *) echo "${ROUGE}Sorry, I can not get a ${STEP} step for you!${NORMAL}"
	;;
esac

if [ ${INSTALL_ZWAVE_DEP} -eq 1 ]; then
	echo "${JAUNE}Start installation of openzwave dep${NORMAL}"
	addon_1_openzwave
fi

rm -rf ${WEBSERVER_HOME}/index.html > /dev/null 2>&1

exit 0

