#!/bin/bash

# A VirtualHost manager for Apache 2.4.41, tested on Ubuntu 20.04 LTS

if [ "$(id -u)" != 0 ]; then
	echo "You must be root or use sudo"
	exit 1
fi

if ! which git > /dev/null; then
	echo -e "You must install git first\n	sudo apt-get install git"
	exit 1
fi

GIT_REPO="https://github.com/fatihgvn/apachep.git"
INSTALL_DIR="/usr/local/apachep"

############################################
###############  Functions  ################
############################################

# Defining password-gen function
gen_pass() {
    MATRIX='0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'
    LENGTH=10
    while [ ${n:=1} -le $LENGTH ]; do
        PASS="$PASS${MATRIX:$(($RANDOM%${#MATRIX})):1}"
        let n+=1
    done
    echo "$PASS"
}

add_repository(){
  local exist_repo=0

  for APT in `find /etc/apt/ -name \*.list`; do
    while read ENTRY ; do
      HOST=`echo $ENTRY | cut -d/ -f3`
      USER=`echo $ENTRY | cut -d/ -f4`
      PPA=`echo $ENTRY | cut -d/ -f5`

      if [ "ppa:$USER/$PPA" = "$1" ]; then
        echo "ppa:$USER/$PPA already added"
        exist_repo=1
        break
      fi
    done <<< $(grep -Po "(?<=^deb\s).*?(?=#|$)" $APT)
  done

  if [[ $exist_repo -eq 0 ]]; then
    echo apt-add-repository $1 -y
    apt-add-repository $1 -y
  fi
}

silent()
{
	if [ "$DEBUG" -eq 1 ] ; then
		"$@"
	else
		"$@" &>/dev/null
	fi
}
get_user()
{
	if [[ "$OSTYPE" == "linux-gnu" ]]; then
		stat -c "%U" "$1"
	else
		ls -l "$1" | awk '{print $3}'
	fi
}
get_group()
{
	if [[ "$OSTYPE" == "linux-gnu" ]]; then
		stat -c "%G" "$1"
	else
		ls -l "$1" | awk '{print $4}'
	fi
}
echo_succ()
{
	$SETCOLOR_SUCCESS
	if [ $# -eq 2 ]; then
		if [ "$1" = "-n" ]; then
			echo -n "$2"
		fi
	else
		echo "$1"
	fi
	$SETCOLOR_NORMAL
}
echo_warn()
{
	$SETCOLOR_WARNING
	if [ $# -eq 2 ]; then
		if [ "$1" = "-n" ]; then
			echo -n "$2"
		fi
	else
		echo "$1"
	fi
	$SETCOLOR_NORMAL
}
echo_fail()
{
	$SETCOLOR_FAILURE
	if [ $# -eq 2 ]; then
		if [ "$1" = "-n" ]; then
			echo -n "$2"
		fi
	else
		echo "$1"
	fi
	$SETCOLOR_NORMAL
}
check_option_empty()
{
	if [[ -z "$1" || "$1" =~ ^-.*$ ]]; then
		echo_fail "$2" 1>&2
		echo
		exit 1
	fi
}

############################################
################  Install  #################
############################################

# add repostories
add_repository ppa:ondrej/php
apt-get update

# ==========================================
# INSTALL APACHE & PHP =====================
# ==========================================
if ! which apache2 > /dev/null; then
	apt-get install apache2 -y
	apt-get install php -y
fi

if ! which php7.4 > /dev/null; then
	# install default version
	apt install php7.4 php7.4-fpm -y
	a2enmod proxy_fcgi setenvif
fi

echo "<VirtualHost *:80>
	ServerAdmin webmaster@localhost
	DocumentRoot /var/www/html

	ErrorLog \${APACHE_LOG_DIR}/error.log
	CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>" > /etc/apache2/sites-available/000-default.conf

systemctl restart apache2.service

# enable modes
a2enmod actions fcgid alias
a2enmod rewrite
a2enmod ssl

# clone repo
if [ -d "$INSTALL_DIR" ]; then
	rm -rf $INSTALL_DIR
fi
git clone $GIT_REPO $INSTALL_DIR

chown -R $SUDO_USER $INSTALL_DIR
chgrp -R www-data $INSTALL_DIR
chmod g+s $INSTALL_DIR

chown -R $SUDO_USER $INSTALL_DIR
chgrp -R www-data $INSTALL_DIR
chmod g+s $INSTALL_DIR

echo " " >> /etc/hosts
echo "# apachep hosts" >> /etc/hosts
echo "127.0.0.1			apachep.local www.apachep.local" >> /etc/hosts

if [/usr/bin/find /etc/apache2/apache2.conf -type f -exec grep -Hn "apachep\/system\/hosts\/\*\.conf" {}]; then
	sed -i "/IncludeOptional\ mods\-enabled\/\*\.conf/a IncludeOptional $INSTALL_DIR/system/hosts/*.conf" /etc/apache2/apache2.conf
fi

# restart apache
systemctl restart apache2.service

# ==========================================
# INSTALL MYSQL ============================
# ==========================================

apt install mysql-client mysql-common mysql-server -y
apt install php7.4-mbstring php7.4-mysql -y

mysql_pass=$(gen_pass)
echo "root:$mysql_pass" > $INSTALL_DIR/system/mysql.passwd

mysql << EOF
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$mysql_pass';
FLUSH PRIVILEGES;
exit;
EOF

# ==========================================
# INSTALL PHPMYADMIN =======================
# ==========================================

echo "phpmyadmin phpmyadmin/dbconfig-install boolean true" | debconf-set-selections
echo "phpmyadmin phpmyadmin/app-password-confirm password $mysql_pass" | debconf-set-selections
echo "phpmyadmin phpmyadmin/mysql/admin-pass password $mysql_pass" | debconf-set-selections
echo "phpmyadmin phpmyadmin/mysql/app-pass password $mysql_pass" | debconf-set-selections
echo "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2" | debconf-set-selections

apt install -y phpmyadmin

# ==========================================
# BUILD CONFIGS ============================
# ==========================================


$INSTALL_DIR/system/bin/add-host apachep.local 7.4

clear

echo "=================================================="
echo "Control Panel: http://apachep.local/"
echo "Mysql User: root"
echo "Mysql Password: $mysql_pass"
echo "=================================================="
