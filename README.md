# apachep

Apacheap automatically installs the following packages on your linux system. It allows you to develop more than one project at the same time by dividing your web projects into virtual hosts in localhost. With the help of PHP-FPM, you can continue to develop your different projects in different versions with more than one php version at the same time.

**Packages Used**
```
apache2
php
php-mbstring
gettext
mysql-client
mysql-common
mysql-server
zip
unzip
net-tools
```

# Tested

Linux|Version(s)|Result
---|---|---
Ubuntu|20.04, 22.04|Success
Debian|-|-
Centos|-|-


# run install

```
bash -c "$(wget -O- https://raw.githubusercontent.com/fatihgvn/apachep/main/install/install-ubuntu.sh)"
```

# Commands

General Usage
```
sudo apachep [method] [args...]
```

## method list

### add-host
Create a new virtual host.

_Runs create-conf and create-ssl respectively_

Argument|detail|default
---|---|---
domain|Domain address to be created|
phpversion|Php version of virtual host|`php -v` to find out the default value

**example**

*Use PHP 7.4*
```
sudo apachep add-host test.local 7.4
```

*Use default PHP*
```
sudo apachep add-host test.local
```

*Use default PHP*
```
sudo apachep add-host test.local default
```

-----

### create-conf
Create configuration file for domain

Argument|detail|default
---|---|---
domain|Domain address to be created|
phpversion|Php version of virtual host|`php -v` to find out the default value

**example**

*Use PHP 7.4*
```
sudo apachep create-conf test.local 7.4
```

*Use default PHP*
```
sudo apachep create-conf test.local
```

*Use default PHP*
```
sudo apachep create-conf test.local default
```

-----

### create-ssl
Create SSL for domain

Argument|detail|default
---|---|---
domain|Domain address to be created|
password|Password for SSL|dummypassword

**example**

*Use own password*
```
sudo apachep create-ssl test.local mypassword
```

*Use default password*
```
sudo apachep create-ssl test.local
```

-----

### install-php
Install new php fpm version

Argument|detail|default
---|---|---
phpversion|PHP version to install|

**example**

```
sudo apachep install-php 7.4
```

-----

### remove-host
Remove an existing host

Argument|detail|default
---|---|---
domain|Domain address to be removed|
with-conf|Will the config file be removed as well?|`false` or `true` default is `true`

**example**

*Remove host with configurations*
```
sudo apachep remove-host test.local
```

*Remove host with configurations*
```
sudo apachep remove-host test.local true
```

*Remove host without configurations*
```
sudo apachep remove-host test.local false
```

-----

### remove-conf
Remove an existing host configuration files

Argument|detail|default
---|---|---
domain|Domain address to be removed|

**example**

```
sudo apachep remove-conf test.local
```
