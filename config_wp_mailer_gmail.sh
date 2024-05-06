#!/bin/bash

DOMAIN=$1
DOMAIN_="${DOMAIN//./_}"
PREFIX="simonho4"

# Check if domain is provided
if [ -z "$DOMAIN" ]; then
    echo "Usage: $0 DOMAIN"
    exit 1
fi

if [[ "$DOMAIN" == "simonholding.us" ]]; then
    WP_DIR="/home2/${PREFIX}/public_html"
else
    WP_DIR="/home2/${PREFIX}/public_html/${DOMAIN_}"
fi

cd $WP_DIR

# Function to retrieve data from 1Password
retrieve_from_1password() {
    local field_name=$1
    local value=$(op read "op://dev/${DOMAIN}/${field_name}")
    if [ $? -ne 0 ]; then
        echo "Failed to retrieve ${field_name} for domain ${DOMAIN}"
        exit 1
    fi
    echo "Successful to retrieve ${field_name} for domain ${DOMAIN}"
}

# retrieve - CLIENT_ID and CLIENT_SECRET from 1password
# CLIENT_ID=$(retrieve_from_1password "client_id")
# CLIENT_SECRET=$(retrieve_from_1password "client_secret")

# Check if WP-CLI is installed
if ! command -v wp &> /dev/null
then
    echo "WP-CLI could not be found. Please install WP-CLI."
    exit
fi

# Check if the plugin is installed, install if not
PLUGIN="wp-mail-smtp" # WP Mail SMTP

if ! wp plugin is-installed $PLUGIN; then
    echo "WP Mail SMTP plugin not found. Installing now..."
    wp plugin install $PLUGIN --activate --allow-root
else
    echo "WP Mail SMTP plugin is already installed."
fi

# Activate the plugin if it is not already active
if ! wp plugin is-active $PLUGIN; then
    wp plugin activate $PLUGIN --allow-root
fi

# Navigate to your WordPress directory
# Update this path to the directory where your WordPress is installed

# Configure WP Mail SMTP settings to use Gmail
REDIRECT_URI="https://${DOMAIN}/wp-admin/options-general.php?page=wp-mail-smtp"

# JSON Configuration for WP Mail SMTP
echo ${CLIENT_ID}
echo ${CLIENT_SECRET}
JSON_STRING=$(cat <<EOM
{
    "mail": {
        "from_email": "contact@${DOMAIN}",
        "from_name": "Contact from https://${DOMAIN}",
        "mailer": "gmail",
        "return_path": true
    },
    "gmail": {
        "client_id": "$CLIENT_ID",
        "client_secret": "$CLIENT_SECRET"
    }
}
EOM
)

wp option update wp_mail_smtp "$JSON_STRING" --format=json

echo "WP Mail SMTP configuration updated successfully."

# synchronize server and local machine timezone because OAuth relies on timestamp verification
tee -a .htaccess <<EOM

php_value date.timezone "America/Los_Angeles"

EOM

