#!/usr/bin/env bash

# Copyright (c) 2021-2026 community-scripts ORG
# Author: Owen Voke (owenvoke)
# License: MIT | https://github.com/community-scripts/ProxmoxVED/raw/main/LICENSE
# Source: https://dragonwilds.runescape.com/

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt install -y \
  lib32gcc-s1 \
  lib32stdc++6
msg_ok "Installed Dependencies"

msg_info "Creating Steam User and Application Directories"
useradd --system \
  --create-home \
  --home-dir /home/steam \
  --shell /usr/sbin/nologin \
  steam
mkdir -p /opt/runescape-dragonwilds/server /opt/steamcmd
chown -R steam:steam /opt/runescape-dragonwilds /opt/steamcmd /home/steam
msg_ok "Created Steam User and Application Directories"

fetch_and_deploy_from_url \
  "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" \
  "/opt/steamcmd"
chown -R steam:steam /opt/steamcmd

msg_info "Installing RuneScape Dragonwilds Dedicated Server"
$STD runuser -u steam -- /opt/steamcmd/steamcmd.sh \
  +force_install_dir /opt/runescape-dragonwilds/server \
  +login anonymous \
  +app_update 4019830 validate \
  +quit
msg_ok "Installed RuneScape Dragonwilds Dedicated Server"

msg_info "Configuring RuneScape Dragonwilds"
mkdir -p /home/steam/.steam/sdk32 /home/steam/.steam/sdk64
cp /opt/steamcmd/linux32/steamclient.so /home/steam/.steam/sdk32/steamclient.so
cp /opt/steamcmd/linux64/steamclient.so /home/steam/.steam/sdk64/steamclient.so
chown -R steam:steam /home/steam/.steam
if [[ -f /opt/runescape-dragonwilds/server/RSDragonwilds/Plugins/Developer/Sentry/Binaries/Linux/crashpad_handler ]]; then
  chmod +x /opt/runescape-dragonwilds/server/RSDragonwilds/Plugins/Developer/Sentry/Binaries/Linux/crashpad_handler
fi
mkdir -p /opt/runescape-dragonwilds/server/RSDragonwilds/Saved/Config/LinuxServer
cat <<EOF >/opt/runescape-dragonwilds/server/RSDragonwilds/Saved/Config/LinuxServer/DedicatedServer.ini
[SectionsToSave]
bCanSaveAllSections=true

[/Script/Dominion.DedicatedServerSettings]
AdminPassword=
OwnerId=
WorldPassword=
ServerName=
DefaultWorldName=
ServerGuid=
EOF
chown -R steam:steam /opt/runescape-dragonwilds/server/RSDragonwilds/Saved
cat <<EOF >/opt/runescape-dragonwilds/dragonwilds.env
# Your RuneScape Dragonwilds player ID, shown at the bottom of the in-game
# settings menu. The server does not start until this is set.
OWNER_ID=
SERVER_NAME="A Dragonwilds Server"
WORLD_NAME="MyWorld"
ADMIN_PASSWORD="$(openssl rand -base64 18 | tr -dc 'a-zA-Z0-9' | cut -c1-13)"
# Leave empty to let anyone join the world.
WORLD_PASSWORD=
# Jagex caps dedicated servers at 6 players.
MAX_PLAYERS=6
SERVER_PORT=7777
QUERY_PORT=27015
# Additional launch arguments, e.g. -multihome=<ip> to bind a specific address.
EXTRA_ARGS=
EOF
chmod 600 /opt/runescape-dragonwilds/dragonwilds.env
msg_ok "Configured RuneScape Dragonwilds"

msg_info "Creating Service"
cat <<'EOF' >/etc/systemd/system/runescape-dragonwilds.service
[Unit]
Description=RuneScape Dragonwilds Dedicated Server
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=steam
Group=steam
WorkingDirectory=/opt/runescape-dragonwilds/server
Environment=LANG=C.UTF-8
Environment=HOME=/home/steam
EnvironmentFile=/opt/runescape-dragonwilds/dragonwilds.env
ExecStart=/opt/runescape-dragonwilds/server/RSDragonwilds/Binaries/Linux/RSDragonwildsServer-Linux-Shipping RSDragonwilds \
  -Port=${SERVER_PORT} \
  -QueryPort=${QUERY_PORT} \
  -ini:DedicatedServer:[/Script/Dominion.DedicatedServerSettings]:OwnerId=${OWNER_ID} \
  -ini:DedicatedServer:[/Script/Dominion.DedicatedServerSettings]:AdminPassword=${ADMIN_PASSWORD} \
  -ini:DedicatedServer:[/Script/Dominion.DedicatedServerSettings]:ServerName=${SERVER_NAME} \
  -ini:DedicatedServer:[/Script/Dominion.DedicatedServerSettings]:DefaultWorldName=${WORLD_NAME} \
  -ini:DedicatedServer:[/Script/Dominion.DedicatedServerSettings]:WorldPassword=${WORLD_PASSWORD} \
  -ini:Game:[/Script/Engine.GameSession]:MaxPlayers=${MAX_PLAYERS} \
  -log -unattended -NoCrashDialog $EXTRA_ARGS
Restart=on-failure
RestartSec=10
KillSignal=SIGINT
TimeoutStopSec=120
StandardOutput=journal+console
StandardError=journal+console

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q runescape-dragonwilds
msg_ok "Created Service"

motd_ssh
customize
cleanup_lxc
