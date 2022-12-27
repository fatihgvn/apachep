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
software="apache2
    php php-mbstring gettext
		mysql-client mysql-common mysql-server
		zip unzip net-tools"

phpfpm="php7.4 php7.4-fpm php7.4-mbstring php7.4-mysql php7.4-zip"

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

############################################
################  Install  #################
############################################

# add repostories
add_repository ppa:ondrej/php

# Updating system
apt-get update

# Installing apt packages
apt-get -y install $software
if [[ $? > 0 ]]
then
	echo "The command failed, exiting."
	exit
fi

# Updating system
apt-get update

# enables modes
a2enmod proxy_fcgi setenvif actions fcgid alias rewrite ssl
phpenmod mbstring

clear

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

# ==========================================
# BUILD CONFIGS ============================
# ==========================================

# restart apache
systemctl restart apache2.service

mysql_pass=$(gen_pass)
echo "root:$mysql_pass" > $INSTALL_DIR/system/mysql.passwd

mysql << EOF
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$mysql_pass';
FLUSH PRIVILEGES;
exit;
EOF

debconf-set-selections <<< "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2"
debconf-set-selections <<< "phpmyadmin phpmyadmin/dbconfig-install boolean true"
debconf-set-selections <<< "phpmyadmin phpmyadmin/mysql/admin-user string root"
debconf-set-selections <<< "phpmyadmin phpmyadmin/mysql/admin-pass password $mysql_pass"
debconf-set-selections <<< "phpmyadmin phpmyadmin/mysql/app-pass password $mysql_pass"
debconf-set-selections <<< "phpmyadmin phpmyadmin/app-password-confirm password $mysql_pass"

apt install -y phpmyadmin

echo "\$cfg['SendErrorReports'] = 'never';" >> /etc/phpmyadmin/config.inc.php
bash $INSTALL_DIR/install/ubuntu/pma/updater.sh


clear

# echo "export VESTA='$VESTA'" > /etc/profile.d/vesta.sh
# chmod 755 /etc/profile.d/vesta.sh
# source /etc/profile.d/vesta.sh
# echo 'PATH=$PATH:'$VESTA'/bin' >> /root/.bash_profile
# echo 'export PATH' >> /root/.bash_profile
# source /root/.bash_profile

# echo "export APACHEP='$INSTALL_DIR'" > /etc/profile.d/apachep.sh
# chmod 755 /etc/profile.d/apachep.sh
# source /etc/profile.d/apachep.sh
#
# echo 'PATH=$PATH:'$INSTALL_DIR'/system/bin' >> /root/.bash_profile
# echo 'export PATH' >> /root/.bash_profile
# source /root/.bash_profile

echo "export APACHEP='$INSTALL_DIR'" > /etc/profile.d/apachep.sh
chmod 755 /etc/profile.d/apachep.sh
source /etc/profile.d/apachep.sh

# echo '' >> /home/$SUDO_USER/.profile
# echo '############### APACHEP ###############' >> /home/$SUDO_USER/.profile
# echo 'export PATH=$PATH:'$INSTALL_DIR'/system/bin' >> /home/$SUDO_USER/.profile
# echo 'export APACHEP='$INSTALL_DIR >> /home/$SUDO_USER/.profile
# source /home/$SUDO_USER/.profile


# a-add-host apachep.local default


echo "=================================================="
echo "Installed Script"
echo "Path: $INSTALL_DIR"
echo "Bin Path: $INSTALL_DIR/system/bin"
echo ""
echo "Control Panel: http://apachep.local/"
echo ""
echo "PhpMyAdmin: http://localhost/phpmyadmin/"
echo "Mysql User: root"
echo "Mysql Password: $mysql_pass"
echo "=================================================="
