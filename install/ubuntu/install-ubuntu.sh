#!/bin/bash
set -e

# Check if the script is run as root.
if [ "$(id -u)" != 0 ]; then
  echo "You must be root or use sudo."
  exit 1
fi

# Process command-line arguments.
# If the --domain parameter is provided, set DOMAIN to its value; otherwise, use the default "dev".
DOMAIN="dev"  # Default value for domain
DNSMASQ_FLAG=false  # Default value for dnsmasq flag (false)
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --domain)
      DOMAIN="$2"
      shift 2
      ;;
    --dnsmasq)
      DNSMASQ_FLAG=true
      shift 1
      ;;
    *)
      echo "Unknown parameter passed: $1"
      exit 1
      ;;
  esac
done

echo "Using domain extension: .$DOMAIN"
if $DNSMASQ_FLAG; then
  echo "DNSMASQ installation flag is enabled."
fi

# Ensure git is installed.
if ! command -v git > /dev/null; then
  echo -e "You must install git first.\n\tsudo apt-get install git"
  exit 1
fi

GIT_REPO="https://github.com/fatihgvn/apachep.git"
INSTALL_DIR="/usr/local/apachep"
software="apache2 php php-mbstring gettext mysql-client mysql-common mysql-server zip unzip net-tools postgresql postgresql-contrib phppgadmin"

############################################
###############  Functions  ################
############################################

# Function to generate a random password.
gen_pass() {
    MATRIX='0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'
    LENGTH=10
    PASS=""
    for (( n=1; n<=LENGTH; n++ )); do
        PASS="$PASS${MATRIX:$(( RANDOM % ${#MATRIX} )):1}"
    done
    echo "$PASS"
}

# Function to add a repository if not already present.
add_repository(){
  local exist_repo=0
  for APT in $(find /etc/apt/ -name "*.list"); do
    while read -r ENTRY; do
      HOST=$(echo "$ENTRY" | cut -d/ -f3)
      USER=$(echo "$ENTRY" | cut -d/ -f4)
      PPA=$(echo "$ENTRY" | cut -d/ -f5)
      if [ "ppa:$USER/$PPA" = "$1" ]; then
        echo "Repository $1 already added."
        exist_repo=1
        break 2
      fi
    done <<< "$(grep -Po '(?<=^deb\s).*?(?=#|$)' "$APT")"
  done
  if [[ $exist_repo -eq 0 ]]; then
    echo "Adding repository $1"
    apt-add-repository "$1" -y
  fi
}

# Function to get the system's primary IP address.
get_system_ip() {
    hostname -I | awk '{print $1}'
}

############################################
################  Install  #################
############################################

# Retrieve the system's IP address.
SYSTEM_IP=$(get_system_ip)
if [ -z "$SYSTEM_IP" ]; then
    echo "Failed to retrieve system IP. Exiting."
    exit 1
fi

echo "System IP: $SYSTEM_IP"

# Add necessary repositories.
add_repository ppa:ondrej/apache2
add_repository ppa:ondrej/php

# Update package lists.
apt-get update

# Install required packages.
apt-get -y install $software
if [[ $? -ne 0 ]]; then
  echo "Package installation failed. Exiting."
  exit 1
fi

# Enable Apache modules and PHP extensions.
# Enable Apache modules individually with error handling.
a2enmod proxy_fcgi  || echo "Module proxy_fcgi not found, skipping..."
a2enmod setenvif    || echo "Module setenvif not found, skipping..."
a2enmod actions     || echo "Module actions not found, skipping..."
a2enmod fcgid       || echo "Module fcgid not found, skipping..."
a2enmod alias       || echo "Module alias not found, skipping..."
a2enmod rewrite     || echo "Module rewrite not found, skipping..."
a2enmod ssl         || echo "Module ssl not found, skipping..."

phpenmod mbstring || echo "PHP module mbstring not found, skipping..."

# Clear the terminal (optional).
clear

# Clone the repository.
if [ -d "$INSTALL_DIR" ]; then
  rm -rf "$INSTALL_DIR"
fi
git clone "$GIT_REPO" "$INSTALL_DIR"

# Set proper ownership and permissions.
chown -R www-data:www-data "$INSTALL_DIR"
chmod g+s "$INSTALL_DIR"

# Optional: Append IncludeOptional directive in Apache configuration if needed.
if /usr/bin/find /etc/apache2/apache2.conf -type f -exec grep -Hn "apachep/system/hosts/\*\.conf" {} \; ; then
  sed -i "/IncludeOptional mods-enabled\/\*\.conf/a IncludeOptional $INSTALL_DIR/system/hosts/*.conf" /etc/apache2/apache2.conf
fi

# Restart Apache to load new configurations.
systemctl restart apache2.service

# If DNSMASQ_FLAG is true, run the dnsmasq installation script.
if $DNSMASQ_FLAG; then
  echo "Running dnsmasq installation script..."
  bash "$INSTALL_DIR/install/ubuntu/dnsmasq/install.sh $DOMAIN"
fi

# MySQL setup.
mysql_pass=$(gen_pass)
echo "root:$mysql_pass" > "$INSTALL_DIR/system/mysql.passwd"

mysql <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$mysql_pass';
FLUSH PRIVILEGES;
EOF

debconf-set-selections <<< "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2"
debconf-set-selections <<< "phpmyadmin phpmyadmin/dbconfig-install boolean true"
debconf-set-selections <<< "phpmyadmin phpmyadmin/mysql/admin-user string root"
debconf-set-selections <<< "phpmyadmin phpmyadmin/mysql/admin-pass password $mysql_pass"
debconf-set-selections <<< "phpmyadmin phpmyadmin/mysql/app-pass password $mysql_pass"
debconf-set-selections <<< "phpmyadmin phpmyadmin/app-password-confirm password $mysql_pass"

apt-get install -y phpmyadmin

echo "\$cfg['SendErrorReports'] = 'never';" >> /etc/phpmyadmin/config.inc.php
bash "$INSTALL_DIR/install/ubuntu/pma/updater.sh"

# --------------------------------------------------
# Update Apache configuration for phppgadmin
# --------------------------------------------------

postgresql_pass=$(gen_pass)
echo "postgres:$postgresql_pass" > "$INSTALL_DIR/system/postgresql.passwd"

if ! grep -q "#Require Local" /etc/apache2/conf-available/phppgadmin.conf; then
  sed -i '/Require Local/ {s/^/# /; N; s/\n/\nAllow from all\n/}' /etc/apache2/conf-available/phppgadmin.conf
fi

if ! grep -q "Require local" /etc/apache2/conf-enabled/phppgadmin.conf; then
  sed -i 's/Require local/Allow from all/gI' /etc/apache2/conf-enabled/phppgadmin.conf
fi

# --------------------------------------------------
# Configure PostgreSQL to allow external connections.
# --------------------------------------------------
# Determine the installed PostgreSQL version (assumes the first found version in /etc/postgresql)
PG_VERSION=$(ls /etc/postgresql | head -n 1)
if [ -n "$PG_VERSION" ]; then
    echo "Configuring PostgreSQL for external connections (version: $PG_VERSION)..."
    
    # Update postgresql.conf to listen on all addresses.
    CONF_FILE="/etc/postgresql/$PG_VERSION/main/postgresql.conf"
    if grep -q "#listen_addresses = 'localhost'" "$CONF_FILE"; then
        sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" "$CONF_FILE"
    else
        # If the listen_addresses setting is already present but not commented out,
        # update it to '*'
        sed -i "s/listen_addresses = 'localhost'/listen_addresses = '*'/" "$CONF_FILE"
    fi

    # Update pg_hba.conf to allow external connections.
    HBA_FILE="/etc/postgresql/$PG_VERSION/main/pg_hba.conf"
    if ! grep -q "host[[:space:]]\+all[[:space:]]\+all[[:space:]]\+0\.0\.0\.0/0" "$HBA_FILE"; then
        echo "host    all             all             0.0.0.0/0               md5" >> "$HBA_FILE"
    fi
else
    echo "PostgreSQL version directory not found. Skipping external connection configuration."
fi

# --------------------------------------------------
# Restart Apache and PostgreSQL services.
# --------------------------------------------------
systemctl restart apache2.service
systemctl restart postgresql.service

sed -i "s/\$conf\['extra_login_security'\] = true;/\$conf\['extra_login_security'\] = false;/g" /etc/phppgadmin/config.inc.php

su - postgres <<EOF
psql <<EOF_SQL
ALTER USER postgres WITH PASSWORD '$postgresql_pass';
\q
EOF_SQL
exit
EOF

# Clear the terminal (optional).
clear

# Configure system environment variable for Apachep.
echo "export APACHEP='$INSTALL_DIR'" > /etc/profile.d/apachep.sh
chmod 755 /etc/profile.d/apachep.sh
source /etc/profile.d/apachep.sh

# Add Apachep bin directory to the PATH via profile.d.
echo "PATH=\$PATH:$INSTALL_DIR/system/bin" >> /etc/profile.d/apachep.sh
source /etc/profile.d/apachep.sh

# Create a command wrapper for Apachep in /usr/bin.
cat <<EOT > /usr/bin/apachep
#!/bin/bash
# Change to Apachep bin directory and execute the given command.
USER_PATH="\$(pwd)"
cd $INSTALL_DIR/system/bin
if [ ! -f "\$1" ]; then
  echo "\$1 command not found"
  exit 1
fi
export USER_PATH && bash \$@
EOT

chmod +x /usr/bin/apachep

# Save the domain extension to a file for use in other scripts.
echo "$DOMAIN" > "$INSTALL_DIR/.domain"

# Save the detected system IP address to a file for use in other scripts.
echo "$SYSTEM_IP" > "$INSTALL_DIR/.ip"


# --------------------------------------------------
# Create a special site for the "apachep" domain
# This site will use INSTALL_DIR as its document root.
# --------------------------------------------------

# Read stored system IP from INSTALL_DIR (if exists), else default.
if [ -f "$INSTALL_DIR/.ip" ]; then
  system_ip=$(cat "$INSTALL_DIR/.ip")
else
  system_ip="127.0.0.1"
fi

# Compose the full domain name for the apachep site.
apachep_domain="apachep.$DOMAIN"
echo "Creating site for domain: $apachep_domain with document root: $INSTALL_DIR"

# Create Apache configuration for the apachep domain.
apachep create-conf "$apachep_domain" "default" "default"

# Path to the generated Apache configuration file.
config_file="$INSTALL_DIR/system/hosts/${apachep_domain}.conf"

# Override the document root in the configuration file to INSTALL_DIR.
# The template contains a placeholder {{path}}, which is replaced here.
escaped_install_dir=$(echo "$INSTALL_DIR" | sed 's_/_\\/_g')
sed -i "s/\/var\/www\/apachep\.$DOMAIN/$escaped_install_dir/g" "$config_file"

# Copy the modified configuration file to Apache's sites-available directory.
cp "$config_file" /etc/apache2/sites-available

# Update /etc/hosts if the apachep domain entry is not present.
if ! grep -q "$apachep_domain" /etc/hosts; then
  echo "$system_ip       $apachep_domain www.$apachep_domain" >> /etc/hosts
fi

# Enable the site configuration and restart Apache.
a2ensite "$apachep_domain.conf"
systemctl restart apache2.service



# Final installation summary.
FINAL_SUMMARY="/final_installation_summary.txt"
cat <<EOT > "$FINAL_SUMMARY"
==================================================
Installed Script
Path: $INSTALL_DIR
Bin Path: $INSTALL_DIR/system/bin

Control Panel: http://apachep.$DOMAIN/
PhpMyAdmin: http://apachep.$DOMAIN/phpmyadmin/
Mysql User: root
Mysql Password: $mysql_pass

PhpPgAdmin: http://apachep.$DOMAIN/phppgadmin/
PG User: postgres
PG Password: $postgresql_pass
==================================================
EOT

# Also display the final summary on screen.
cat "$FINAL_SUMMARY"
