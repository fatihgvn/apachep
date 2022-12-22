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
apt-get update

# ==========================================
# INSTALL APACHE & PHP =====================
# ==========================================
if ! which apache2 > /dev/null; then
	apt-get install apache2 -y
fi

if ! which php7.4 > /dev/null; then
	# install default version
	apt install php7.4 php7.4-fpm -y
	a2enmod proxy_fcgi setenvif
fi

echo "<VirtualHost *:80>
	ServerAdmin webmaster@localhost
	DocumentRoot /var/www/html

	<FilesMatch \\.php\$>
		SetHandler \"proxy:unix:/run/php/php7.4-fpm.sock|fcgi://localhost\"
	</FilesMatch>

	ErrorLog \${APACHE_LOG_DIR}/error.log
	CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>" > /etc/apache2/sites-available/000-default.conf

systemctl restart apache2.service

# enable modes
a2enmod actions fcgid alias
a2enmod rewrite
a2enmod ssl

# clone repo
if [ -d "/usr/local/apachep" ]; then
	rm -rf /usr/local/apachep
fi
git clone $GIT_REPO /usr/local/apachep

chown -R $SUDO_USER /usr/local/apachep
chgrp -R www-data /usr/local/apachep
chmod g+s /usr/local/apachep

chown -R $SUDO_USER /var/www/html
chgrp -R www-data /var/www/html
chmod g+s /var/www/html

echo " " >> /etc/hosts
echo "# apachep hosts" >> /etc/hosts

if [find /etc/apache2/apache2.conf -type f -exec grep -Hn "\/usr\/local\/apachep\/system\/hosts\/\*\.conf" {}]; then
	sed -i '/IncludeOptional\ mods\-enabled\/\*\.conf/a IncludeOptional /usr/local/apachep/system/hosts/*.conf' /etc/apache2/apache2.conf
fi

# restart apache
systemctl restart apache2.service

# ==========================================
# INSTALL MYSQL ============================
# ==========================================

apt install mysql-client mysql-common mysql-server -y
apt install php7.4-mbstring php7.4-mysql -y

mysql_pass=$(gen_pass)
echo "root:$mysql_pass" > /var/www/html/system/mysql.passwd

mysql << EOF
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$mysql_pass';
FLUSH PRIVILEGES;
exit;
EOF

# ==========================================
# INSTALL PHPMYADMIN =======================
# ==========================================
apt install phpmyadmin -y
