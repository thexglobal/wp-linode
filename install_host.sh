#!/bin/bash

# Usage: ./install_host.sh DOMAIN

# Variables
DOMAIN=$1
DOMAIN_="${DOMAIN//./_}"
WP_URL="https://$DOMAIN"
EMAIL="admin@${DOMAIN}"
HOST_PREFIX="wp"
DB_PREFIX="wp"

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then 
  echo "Please run as root"
  exit
fi

# Check if domain is provided
if [ -z "$DOMAIN" ]; then
    echo "Usage: $0 DOMAIN"
    exit 1
fi

WP_DIR="/var/www/$DOMAIN_"
DB_NAME="${HOST_PREFIX}_${DOMAIN_}"
DB_USER="${HOST_PREFIX}_${DOMAIN_}"
DB_PASSWORD=$(openssl rand -base64 12) # Generate random password for WordPress database user

DB_ROOT_PASSWORD=$(openssl rand -base64 12) # Generate random Root password for MariaDB

# Create WordPress Database and User config for auto login to mysql
tee ~/.my.cnf <<EOM
[client]
user=root
password=$DB_ROOT_PASSWORD
host=localhost
EOM

# Step 1: Prepare system

# Update system
sudo timedatectl set-timezone America/Los_Angeles
apt update && apt upgrade -y

# Install Nginx, MariaDB, PHP, and necessary PHP extensions
apt install nginx mariadb-server php-fpm php-mysql php-dom php-simplexml php-ssh2 php-imagick php-gd php-curl php-mbstring php-xml php-zip wget certbot python3-certbot-nginx unzip -y

# Start and enable services
systemctl start nginx
systemctl enable nginx
systemctl start mariadb
systemctl enable mariadb

# Secure MariaDB installation
mysql_secure_installation <<EOM
y
$DB_ROOT_PASSWORD
$DB_ROOT_PASSWORD
y
y
y
y
EOM

# Step 2: Create MySQL Database and User

echo "Creating MySQL database and user..."
mysql -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`;"
mysql -e "CREATE USER \`${DB_USER}\`@'localhost' IDENTIFIED BY '${DB_PASSWORD}'; GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO \`${DB_USER}\`@'localhost'; FLUSH PRIVILEGES;"

# Step 3: Download and Configure WordPress via WP-CLI

# Install WP-CLI
echo "Installing WP-CLI..."
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
sudo mv wp-cli.phar /usr/local/bin/wp

mkdir -p "$WP_DIR"
cd "$WP_DIR"

echo "Downloading WordPress..."
wp core download --path="$WP_DIR" --allow-root

# Create wp-config.php
echo "Configuring WordPress..."
wp config create --dbname=$DB_NAME --dbuser=$DB_USER --dbpass=$DB_PASSWORD --dbprefix=${DB_PREFIX}_ --path="$WP_DIR" --allow-root

# Install WordPress
echo "Installing WordPress..."
ADMIN_USER="admin"
ADMIN_PASSWORD="$(openssl rand -base64 12)"
TITLE="New WordPress Site"

wp core install --url="$DOMAIN" --title="$TITLE" --admin_user="$ADMIN_USER" --admin_password="$ADMIN_PASSWORD" --admin_email="${ADMIN_USER}@${DOMAIN}" --path="$WP_DIR" --allow-root

# Define or Update WP_MEMORY_LIMIT
# wp config set WP_MEMORY_LIMIT '512M' --raw --type=constant --allow-root --path="$WP_DIR" 

# Set up correct permissions
echo "Setting up correct permissions..."
find "$WP_DIR" -type d -exec chmod 755 {} \;
find "$WP_DIR" -type f -exec chmod 644 {} \;

# Step 4: Configure Nginx
cat > /etc/nginx/sites-available/$DOMAIN <<EOM
server {
    client_max_body_size 20M;
    listen 80;
    server_name $DOMAIN www.$DOMAIN;
    root $WP_DIR;
    
    index index.php index.html index.htm;
    
    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOM

# Increase PHP Limits
tee $WP_DIR/php.ini <<EOM

upload_max_filesize = 64M
post_max_size = 128M
max_execution_time = 300
max_input_time = 300
memory_limit = 256M
EOM

# Enable Nginx site
ln -s /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/

# Reload Nginx to apply configuration
systemctl reload nginx

# Step 5: Obtain SSL Certificate with Let's Encrypt (Assuming certbot is installed)
echo "Obtaining SSL Certificate..."
certbot --nginx -m $EMAIL --agree-tos --no-eff-email -d $DOMAIN -d www.$DOMAIN

# Step 6: Print information

echo "WordPress installation completed for $WP_URL"
echo "==============================="
echo "Wordpress folder: $WP_DIR"
echo "Database name: $DB_NAME"
echo "Database user: $DB_USER"
echo "Database password: $DB_PASSWORD"
echo "==============================="
echo "Admin URL: ${WP_URL}/wp-admin"
echo "Admin password: $ADMIN_PASSWORD"
echo "DB root password: ${DB_ROOT_PASSWORD}"

# Step 7: Install plugins
echo "Installing wpforms-lite, elementor, elementor pro, "
# Install and activate free plugins
wp plugin install elementor --activate --allow-root
wp plugin install wpforms-lite --activate --allow-root

# Install and activate Elementor Pro if it exists
ELEMENTOR_PRO_ZIP=~/wp-linode/elementor-pro-3.21.2.zip
cp $ELEMENTOR_PRO_ZIP $WP_DIR/elementor-pro.zip
if [[ -f "$ELEMENTOR_PRO_ZIP" ]]; then
    wp plugin install elementor-pro.zip --activate --allow-root
else
    echo "Elementor Pro zip file does not exist at specified path: $ELEMENTOR_PRO_ZIP"
fi

