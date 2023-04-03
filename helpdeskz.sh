#!/bin/bash -e

## Deployment variables
#<UDF name="site_url" label="The site url">
#<UDF name="db_user" label="The user for the MySQL database">
#<UDF name="db_password" label="The password for the MySQL database user">
#<UDF name="cert_email" label="The email for the SSL certificate administrator">

exec > >(tee -i /var/log/stackscript.log)

sudo apt update
sudo apt install apache2 php libapache2-mod-php mysql-server php-mysql php-intl php-xml php-xmlrpc php-curl php-gd php-imagick php-cli php-dev php-imap php-mbstring php-opcache php-soap php-zip unzip certbot python3-certbot-apache -y 2>/dev/null
sudo a2enmod rewrite

wget https://github.com/helpdesk-z/helpdeskz-dev/archive/refs/heads/master.zip
unzip master.zip -d /var/www/

## Configure DB

mysql -u root -e "CREATE DATABASE helpdeskz; CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD'; GRANT ALL PRIVILEGES ON *.* to '$DB_USER'@'localhost' WITH GRANT OPTION;"
mv /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-available/000-default.conf.old

## Configure Apache

echo '<VirtualHost *:80>
        ServerAdmin webmaster@localhost
        DocumentRoot /var/www/helpdeskz-dev-master
        ErrorLog ${APACHE_LOG_DIR}/error.log
        CustomLog ${APACHE_LOG_DIR}/access.log combined
        <Directory "/var/www/helpdeskz-dev-master">
            AllowOverride All
        </Directory>
</VirtualHost>' > /etc/apache2/sites-available/000-default.conf

## Configure HelpDeskZ

echo "<?php
namespace Config;
use CodeIgniter\Config\BaseConfig;
class Helpdesk extends BaseConfig
{
    const DB_HOST = 'localhost';
    const DB_USER = '$DB_USER';
    const DB_PASSWORD = '$DB_PASSWORD';
    const DB_NAME = 'helpdeskz';
    const DB_PREFIX = 'hdz_';
    const DB_PORT = 3306;
    const SITE_URL = 'https://$SITE_URL';
    const UPLOAD_PATH = FCPATH.'upload';
    const DEFAULT_LANG = 'en';
    const STAFF_URI = 'staff';
}" > /var/www/helpdeskz-dev-master/hdz/app/Config/Helpdesk.php

## Configure .htaccess

echo '<IfModule mod_rewrite.c>
        Options +FollowSymlinks
        RewriteEngine On
        RewriteCond %{REQUEST_FILENAME} !-d
        RewriteRule ^(.*)/$ /$1 [L,R=301]
        RewriteCond %{HTTPS} !=on
        RewriteCond %{HTTP_HOST} ^www\.(.+)$ [NC]
        RewriteRule ^ http://%1%{REQUEST_URI} [R=301,L]
        RewriteCond %{REQUEST_FILENAME} !-f
        RewriteCond %{REQUEST_FILENAME} !-d
        RewriteRule ^(.*)$ index.php/$1 [L]
        RewriteCond %{HTTP:Authorization} .
        RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization}]
</IfModule>
<IfModule !mod_rewrite.c>
    ErrorDocument 404 index.php
</IfModule>' > /var/www/helpdeskz-dev-master/.htaccess

## Configure .htaccess

echo '<?php
phpinfo( );
?>' > /var/www/helpdeskz-dev-master/info.php

## Configure permissions

chmod 0777 /var/www/helpdeskz-dev-master/hdz/writable -R
chmod 0777 /var/www/helpdeskz-dev-master/upload -R

# For this line to work the DNS needs to be pointing to the proper linode public IP, otherwise it will fail and the installation will only work on plain http
certbot --apache --non-interactive --agree-tos -m $CERT_EMAIL --domains $SITE_URL --redirect

reboot
