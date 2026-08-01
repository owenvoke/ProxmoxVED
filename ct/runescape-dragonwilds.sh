#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../misc/build.func" 2>/dev/null || source <(curl -fsSL "${COMMUNITY_SCRIPTS_URL:-https://raw.githubusercontent.com/community-scripts/ProxmoxVED/main}/misc/build.func")
# Copyright (c) 2021-2026 community-scripts ORG
# Author: Owen Voke (owenvoke)
# License: MIT | https://github.com/community-scripts/ProxmoxVED/raw/main/LICENSE
# Source: https://dragonwilds.runescape.com/

APP="RuneScape-Dragonwilds"
var_tags="${var_tags:-gaming;server}"
var_cpu="${var_cpu:-4}"
var_ram="${var_ram:-8192}"
var_disk="${var_disk:-20}"
var_os="${var_os:-debian}"
var_version="${var_version:-13}"
var_arm64="${var_arm64:-no}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if [[ ! -x /opt/steamcmd/steamcmd.sh || ! -d /opt/runescape-dragonwilds/server ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  msg_info "Stopping ${APP}"
  systemctl stop runescape-dragonwilds
  msg_ok "Stopped ${APP}"

  create_backup /opt/runescape-dragonwilds/server/RSDragonwilds/Saved /opt/runescape-dragonwilds/dragonwilds.env

  msg_info "Updating ${APP}"
  if $STD runuser -u steam -- /opt/steamcmd/steamcmd.sh \
    +force_install_dir /opt/runescape-dragonwilds/server \
    +login anonymous \
    +app_update 4019830 validate \
    +quit; then
    msg_ok "Updated ${APP}"
  else
    restore_backup
    systemctl start runescape-dragonwilds
    msg_error "Failed to update ${APP}"
    exit 1
  fi

  restore_backup

  msg_info "Starting ${APP}"
  systemctl start runescape-dragonwilds
  msg_ok "Started ${APP}"
  msg_ok "Updated Successfully!"
  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Set your Owner ID and the remaining options in:${CL}"
echo -e "${TAB}/opt/runescape-dragonwilds/dragonwilds.env"
echo -e "${INFO}${YW} Then start the server:${CL}"
echo -e "${TAB}systemctl start runescape-dragonwilds"
echo -e "${INFO}${YW} Join the world from the Public tab of the Worlds screen:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}${IP}:7777${CL}"
echo -e "${INFO}${YW} Required ports:${CL} ${BGN}7777 UDP and 27015 UDP${CL}"
