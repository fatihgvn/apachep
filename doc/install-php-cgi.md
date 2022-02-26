## add ondrej/php repository

```
sudo add-apt-repository ppa:ondrej/php
```


## install php for versions
```
sudo apt install php5.6-cli php5.6-xml php5.6-mysql
sudo apt install php7.0-cli php7.0-xml php7.0-mysql
sudo apt install php7.1-cli php7.1-xml php7.1-mysql
sudo apt install php7.2-cli php7.2-xml php7.2-mysql
sudo apt install php7.3-cli php7.3-xml php7.3-mysql
sudo apt install php7.4-cli php7.4-xml php7.4-mysql
sudo apt install php8.0-cli php8.0-xml php8.0-mysql
```

## set default php version
```
sudo update-alternatives --set php /usr/bin/php7.2
```

## disable php versions
```
sudo a2dismod php5.6
sudo a2dismod php7.0
sudo a2dismod php7.1
sudo a2dismod php7.2
sudo a2dismod php7.3
sudo a2dismod php7.4
sudo a2dismod php8.0
```

## enable php versions
```
sudo a2enmod php5.6
sudo a2enmod php7.0
sudo a2enmod php7.1
sudo a2enmod php7.2
sudo a2enmod php7.3
sudo a2enmod php7.4
sudo a2enmod php8.0
```

## restart apache
```
sudo systemctl restart apache2
```
