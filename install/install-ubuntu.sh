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

# Default vars (don't change them)
PMA_PATH="/usr/share/phpmyadmin"
PMA_VERSION="latest"
PMA_LANGUAGE="all-languages"
PMA_CURRENT_VERSION=
PMA_TEMP_DIR="'./tmp/'"
PMA_USER=
PMA_GROUP=
PMA_USER_OPTION="..."
PMA_GROUP_OPTION="..."
PMA_ISSET=0
FORCE_INSTALL=0
LATEST=0
DEBUG=0
HELP=0
NO_ASK=0
CRON_MODE=0

# Styling and cron mode
if [ "Z$(ps o comm="" -p $(ps o ppid="" -p $$))" == "Zcron" -o \
     "Z$(ps o comm="" -p $(ps o ppid="" -p $(ps o ppid="" -p $$)))" == "Zcron" ]; then
	SETCOLOR_SUCCESS=
	SETCOLOR_WARNING=
	SETCOLOR_FAILURE=
	SETCOLOR_NORMAL=
	BOLD_TEXT=
	NORMAL_TEXT=
	CRON_MODE=1
else
	SETCOLOR_SUCCESS="echo -en \\033[1;32m"
	SETCOLOR_WARNING="echo -en \\033[1;33m"
	SETCOLOR_FAILURE="echo -en \\033[1;31m"
	SETCOLOR_NORMAL="echo -en \\033[0;39m"
	BOLD_TEXT=$(tput bold)
	NORMAL_TEXT=$(tput sgr0)
fi

# Add blank line before output
echo

# Prepare some vars
PMA_LATEST_VERSION_INFO_URL="https://www.phpmyadmin.net/home_page/version.php"
if [ "$PMA_VERSION" = "latest" ]; then
	LATEST=1
	PMA_VERSION=$(wget -q -O /tmp/pma_lastest.html $PMA_LATEST_VERSION_INFO_URL && sed -ne '1p' /tmp/pma_lastest.html);
fi
PMA_DOWNLOAD_URL="https://files.phpmyadmin.net/phpMyAdmin/${PMA_VERSION}/phpMyAdmin-${PMA_VERSION}-${PMA_LANGUAGE}.tar.gz"
BLOWFISH_SECRET=$(tr -dc 'A-Za-z0-9' < /dev/urandom | dd bs=1 count=32 2>/dev/null)
check_option_empty "$PMA_PATH" "Path to phpMyAdmin directory not given in -p|--path= option!"
PMA_PARENT_PATH="$(echo "$PMA_PATH" | sed 's/\/[^/]*$//' | sed 's/\/$//')"
PMA_DIRNAME="$(echo "$PMA_PATH" | sed 's/.*\///')"
if [ -z "$PMA_PARENT_PATH" ]; then
	PMA_PARENT_PATH="/"
fi
if [ -z "$PMA_DIRNAME" ]; then
	PMA_DIRNAME="phpmyadmin"
fi
if [ "$PMA_PARENT_PATH" = "/" ]; then
	PMA_PATH="/${PMA_DIRNAME}"
else
	PMA_PATH="${PMA_PARENT_PATH}/${PMA_DIRNAME}"
fi
if [ -z "$PMA_USER" ]; then
	PMA_USER=$(get_user "$PMA_PARENT_PATH")
fi
if [ -z "$PMA_GROUP" ]; then
	PMA_GROUP=$(get_group "$PMA_PARENT_PATH")
fi

# Check vars
check_option_empty "$PMA_VERSION" "phpMyAdmin version not given in -v|--version= option!"
check_option_empty "$PMA_TEMP_DIR" "TEMP_DIR value not given in -t|--temp-dir= option!"
check_option_empty "$PMA_USER_OPTION" "User not given in -u|--user= option!"
check_option_empty "$PMA_GROUP_OPTION" "Group not given in -g|--group= option!"
silent cd "$PMA_PARENT_PATH"
if ! [ "$(pwd)" = "$PMA_PARENT_PATH" ]; then
	echo_fail "Can't get up in a directory for phpMyAdmin directory (${PMA_PARENT_PATH})!" 1>&2
	echo
	exit 1
fi
if ! [[ "$PMA_VERSION" =~ ^([0-9]+\.[0-9]+\.[0-9]+|[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+|latest)$ ]]; then
	echo_fail "Wrong format of version given (must be like this \"1.2.3\" or \"latest\") "
	echo_fail "or url with latest version not work (${PMA_LATEST_VERSION_INFO_URL}) "
	echo_fail "if you sets latest version!"
	echo
	exit 1
fi
TEMP_DIR_STR="<?php define('TEMP_DIR', ${PMA_TEMP_DIR});"
if ! [[ "$(echo "$TEMP_DIR_STR" | php -l 2>&1)" =~ "No syntax errors" ]]; then
	echo_fail "Wrong php syntax for TEMP_DIR value or php vars not escaped!"
	echo_fail "Value must be in double quotes (ex: \"'./tmp/'\")."
	echo
	exit 1
fi
if ! [[ "$PMA_USER" =~ ^[a-z_][a-z0-9_]{0,30}$ ]]; then
	echo_fail "Wrong username given!"
	echo
	exit 1
else
	silent grep "${PMA_USER}:" /etc/passwd
	if [ $? -ne 0 ]; then
		echo_fail "Given username not found!"
		echo
		exit 1
	fi
fi
if ! [[ "$PMA_GROUP" =~ ^[a-z_][a-z0-9_]{0,30}$ ]]; then
	echo_fail "Wrong group given!"
	echo
	exit 1
else
	silent grep ":${PMA_GROUP}" /etc/passwd
	if [ $? -ne 0 ]; then
		echo_fail "Given group not found!"
		echo
		exit 1
	fi
fi

# Pre-install info
echo -n "Directory: "
echo_succ "$PMA_PATH"
echo -n "Directory owner: "
echo_succ "${PMA_USER}:${PMA_GROUP}"
echo -n "Installed version: "
if [ -d "$PMA_PATH" ]; then
	PMA_ISSET=1
	PMA_CURRENT_VERSION=$(sed -n 's/^Version \(.*\)$/\1/p' ${PMA_PATH}/README)
	if ! [ -z "$PMA_CURRENT_VERSION" ]; then
		echo_succ "$PMA_CURRENT_VERSION"
	else
		echo_fail "unknown version"
	fi
else
	echo_succ "not installed"
fi
echo -n "Version to install: "
if [ $LATEST -eq 1 ]; then
	echo_succ "${PMA_VERSION} (latest)"
else
	echo_succ "$PMA_VERSION"
fi
echo -n "Language to install: "
if [ "$PMA_LANGUAGE" = "all-languages" ]; then
	echo_succ "all"
else
	echo_succ "$PMA_LANGUAGE"
fi
echo -n "Force install: "
if [ $FORCE_INSTALL -eq 1 ]; then
	echo_warn "enabled"
else
	echo_succ "disabled"
fi
echo -n "TEMP_DIR value: "
if [ "$PMA_TEMP_DIR" = "'./tmp/'" ]; then
	echo_warn "$PMA_TEMP_DIR"
else
	echo_succ "$PMA_TEMP_DIR"
fi

# Check need to update
if [ "$PMA_CURRENT_VERSION" = "$PMA_VERSION" ]; then
	echo
	if [ $LATEST -eq 1 ]; then
		echo_succ "phpMyAdmin already up to date."
	else
		echo_succ "Selected version of phpMyAdmin already installed."
	fi
	if [ $FORCE_INSTALL -eq 1 ]; then
		echo_warn "Force install enabled. phpMyAdmin will be reinstalled."
	else
		echo
		exit 0
	fi
fi

echo

# Backup old version
if [ $PMA_ISSET -eq 1 ]; then
	echo -n "Creating backup... "
	CUR_TIME=$(date +%s)
	silent tar -zcvf "${PMA_PATH}_${CUR_TIME}".tar.gz "$PMA_PATH"
	if [ -f "${PMA_PATH}_${CUR_TIME}.tar.gz" ]; then
		rm -rf "$PMA_PATH"
		echo_succ -n "Created"
		echo " (${PMA_PATH}_${CUR_TIME}.tar.gz)"
	else
		echo_fail "Not created"
		echo
		exit 1
	fi
fi

# Download new version
cd "$PMA_PARENT_PATH"
echo -n "Downloading new version... "
silent wget -c "$PMA_DOWNLOAD_URL"
if [ -f "${PMA_PARENT_PATH}/phpMyAdmin-${PMA_VERSION}-${PMA_LANGUAGE}.tar.gz" ]; then
	echo_succ "Done"
else
	echo_fail "Unable to download!"
	echo
	exit 1
fi

# Install
echo -n "Installing... "
silent tar xzf phpMyAdmin-"$PMA_VERSION"-"$PMA_LANGUAGE".tar.gz
silent mv phpMyAdmin-"$PMA_VERSION"-"$PMA_LANGUAGE" "$PMA_DIRNAME"
silent rm phpMyAdmin-"$PMA_VERSION"-"$PMA_LANGUAGE".tar.gz*
if [ -d "$PMA_PATH" ]; then
	echo_succ "Done"
else
	echo_fail "Can't install!"
	echo
	exit 1
fi
rm -rf "$PMA_PATH"/setup
chown -R "${PMA_USER}:${PMA_GROUP}" "$PMA_PATH"

# Configure
echo -n "Configuring... "
if [[ "$PMA_TEMP_DIR" = "'./tmp/'" && "${PMA_USER}:${PMA_GROUP}" = "root:root" ]]; then
	mkdir "$PMA_PATH"/tmp
	chmod -R 777 "$PMA_PATH"/tmp
fi
sed -i "s|define('TEMP_DIR',.*;|define('TEMP_DIR', ${PMA_TEMP_DIR});|" \
	"$PMA_PATH"/libraries/vendor_config.php
sed -i "s|define('CONFIG_DIR',.*;|define('CONFIG_DIR', '${PMA_PATH}/');|" \
	"$PMA_PATH"/libraries/vendor_config.php
cp "$PMA_PATH"/config.sample.inc.php "$PMA_PATH"/config.inc.php
sed -i "s|\$cfg\['blowfish_secret'\].*;|\$cfg['blowfish_secret'] = '${BLOWFISH_SECRET}';|" \
	"$PMA_PATH"/config.inc.php
echo_succ "Done"
echo

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
