#!/usr/bin/env bash
# Engine comes from community-scripts/core; this repo only ships the scripts.
# A local core checkout wins (COMMUNITY_SCRIPTS_CORE_DIR, else a sibling ../core),
# so a fork or branch of core can be tested without editing this file.
_cs_boot="${COMMUNITY_SCRIPTS_CORE_DIR:-$(dirname "${BASH_SOURCE[0]}")/../../core}/core/build.func"
source "$_cs_boot" 2>/dev/null || source <(curl -fsSL "${COMMUNITY_SCRIPTS_CORE_URL:-https://raw.githubusercontent.com/community-scripts/core/main}/core/build.func")
# Copyright (c) 2021-2026 community-scripts ORG
# Author: Owen Voke (owenvoke)
# License: MIT | https://github.com/community-scripts/ProxmoxVED/raw/main/LICENSE
# Source: https://github.com/ellite/scrob

APP="Scrob"
var_tags="${var_tags:-media;tracking}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-4096}"
var_disk="${var_disk:-10}"
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

  if [[ ! -d /opt/scrob ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  if check_for_gh_release "scrob" "ellite/scrob"; then
    msg_info "Stopping Services"
    systemctl stop scrob-frontend scrob-backend
    msg_ok "Stopped Services"

    create_backup /opt/scrob/.env

    CLEAN_INSTALL=1 fetch_and_deploy_gh_release "scrob" "ellite/scrob" "tarball"

    restore_backup

    msg_info "Updating Backend"
    sed -i "s|^APP_VERSION=.*|APP_VERSION=$(cat ~/.scrob)|" /opt/scrob/.env
    cd /opt/scrob/backend
    $STD uv sync --frozen --no-dev --python 3.12
    $STD /opt/scrob/backend/.venv/bin/python -m alembic upgrade head
    msg_ok "Updated Backend"

    msg_info "Building Frontend"
    cd /opt/scrob/frontend
    $STD npm ci
    $STD npm run build
    msg_ok "Built Frontend"

    msg_info "Starting Services"
    systemctl start scrob-backend scrob-frontend
    msg_ok "Started Services"
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
echo -e "${GATEWAY}${BGN}http://${IP}:7330${CL}"
