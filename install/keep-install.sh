#!/usr/bin/env bash

# Copyright (c) 2021-2026 community-scripts ORG
# Author: Owen Voke (owenvoke)
# License: MIT | https://github.com/community-scripts/DevScripts/raw/main/LICENSE
# Source: https://github.com/owenvoke/keep

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt install -y nginx
msg_ok "Installed Dependencies"

PHP_VERSION="8.5" PHP_FPM="YES" setup_php
setup_composer
NODE_VERSION="24" setup_nodejs

fetch_and_deploy_gh_release "keep" "owenvoke/keep" "tarball"

msg_info "Setting up Keep"
mkdir -p /opt/keep_data
touch /opt/keep_data/database.sqlite
cat <<EOF >/opt/keep_data/.env
APP_NAME=Keep
APP_ENV=production
APP_KEY=base64:$(openssl rand -base64 32)
APP_DEBUG=false
APP_URL=http://${LOCAL_IP}
# Comma-separated IPs of any reverse proxy in front of Keep (e.g. cloudflared, NPM, Traefik)
# TRUSTED_PROXIES=

DB_CONNECTION=sqlite
DB_DATABASE=/opt/keep_data/database.sqlite

SESSION_DRIVER=database
CACHE_STORE=database
QUEUE_CONNECTION=database

LOG_CHANNEL=stack
LOG_STACK=single
LOG_LEVEL=warning

MAIL_MAILER=log

# No mailer is configured, so verification emails could never arrive
EMAIL_VERIFICATION_DISABLED=true
REGISTRATION_DISABLED=false
EOF
ln -sf /opt/keep_data/.env /opt/keep/.env
cd /opt/keep
$STD composer install --no-dev --optimize-autoloader --no-interaction
$STD npm ci --ignore-scripts
$STD npm run build
rm -rf node_modules
$STD php artisan migrate --force
$STD php artisan optimize
$STD php artisan app:sync
chown -R www-data:www-data /opt/keep /opt/keep_data
chmod 600 /opt/keep_data/.env
msg_ok "Set up Keep"

msg_info "Configuring Nginx"
PHP_SOCK=$(get_php_fpm_socket)
cat <<EOF >/etc/nginx/sites-available/keep
server {
    listen 80;
    server_name _;
    root /opt/keep/public;

    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-Content-Type-Options "nosniff";

    index index.php;
    charset utf-8;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }

    error_page 404 /index.php;

    location ~ \.php\$ {
        fastcgi_pass unix:${PHP_SOCK};
        fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_hide_header X-Powered-By;
    }

    location ~ /\.(?!well-known).* {
        deny all;
    }
}
EOF
nginx_enable_site "keep"
msg_ok "Configured Nginx"

msg_info "Creating Scheduled Sync"
cat <<EOF >/etc/cron.d/keep
0 3 * * * www-data cd /opt/keep && /usr/bin/php artisan app:sync >/dev/null 2>&1
EOF
chmod 644 /etc/cron.d/keep
msg_ok "Created Scheduled Sync"

motd_ssh
customize
cleanup_lxc
