#!/usr/bin/env bash
_CS_DEFAULT_URL="https://raw.githubusercontent.com/community-scripts/DevScripts/main"
_cs_boot="${COMMUNITY_SCRIPTS_CORE_DIR:-$(dirname "${BASH_SOURCE[0]}")/../../core}/core/build.func"
source "$_cs_boot" 2>/dev/null || source <(curl -fsSL "${COMMUNITY_SCRIPTS_CORE_URL:-https://raw.githubusercontent.com/community-scripts/core/main}/core/build.func")
# Copyright (c) 2021-2026 community-scripts ORG
# Author: Owen Voke (owenvoke)
# License: MIT | https://github.com/community-scripts/DevScripts/raw/main/LICENSE
# Source: https://github.com/owenvoke/keep

APP="Keep"
var_tags="${var_tags:-castles;travel}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-2048}"
var_disk="${var_disk:-6}"
var_os="${var_os:-debian}"
var_version="${var_version:-13}"
#var_arm64="${var_arm64:-no}" # unset = ask the user; set yes/no only when verified
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if [[ ! -d /opt/keep ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  if check_for_gh_release "keep" "owenvoke/keep"; then
    msg_info "Stopping Keep"
    systemctl stop php8.5-fpm
    msg_ok "Stopped Keep"

    setup_composer
    NODE_VERSION="24" setup_nodejs

    CLEAN_INSTALL=1 fetch_and_deploy_gh_release "keep" "owenvoke/keep" "tarball"

    msg_info "Updating Keep"
    ln -sf /opt/keep_data/.env /opt/keep/.env
    cd /opt/keep
    $STD composer install --no-dev --optimize-autoloader --no-interaction
    $STD npm ci --ignore-scripts
    $STD npm run build
    rm -rf node_modules
    $STD php artisan migrate --force
    $STD php artisan optimize
    chown -R www-data:www-data /opt/keep /opt/keep_data
    msg_ok "Updated Keep"

    msg_info "Starting Keep"
    systemctl start php8.5-fpm
    msg_ok "Started Keep"
    msg_ok "Updated successfully!"
  fi
  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW}Access it using the following URL:${CL}"
echo -e "${GATEWAY}${BGN}http://${IP}${CL}"
