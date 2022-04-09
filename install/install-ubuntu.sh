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
rm /var/www/html/index.html
git clone $GIT_REPO /var/www/html

echo " " >> /etc/hosts
echo "# apachep hosts" >> /etc/hosts

# restart apache
systemctl restart apache2.service

xdg-open http://localhost/
