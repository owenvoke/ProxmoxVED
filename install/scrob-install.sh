#!/usr/bin/env bash

# Copyright (c) 2021-2026 community-scripts ORG
# Author: Owen Voke (owenvoke)
# License: MIT | https://github.com/community-scripts/ProxmoxVED/raw/main/LICENSE
# Source: https://github.com/ellite/scrob

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

PG_VERSION="16" setup_postgresql
PG_DB_NAME="scrob" PG_DB_USER="scrob" setup_postgresql_db
PYTHON_VERSION="3.12" setup_uv
NODE_VERSION="22" setup_nodejs

fetch_and_deploy_gh_release "scrob" "ellite/scrob" "tarball"

msg_info "Configuring Scrob"
mkdir -p /opt/scrob_data
cat <<EOF >/opt/scrob/.env
DATABASE_URL=postgresql+asyncpg://${PG_DB_USER}:${PG_DB_PASS}@localhost:5432/${PG_DB_NAME}
SECRET_KEY=$(openssl rand -hex 32)
SERVER_URL=http://${LOCAL_IP}:7330
DATA_DIR=/opt/scrob_data
APP_VERSION=$(cat ~/.scrob)
ENABLE_REGISTRATIONS=false
TZ=UTC
EOF
msg_ok "Configured Scrob"

msg_info "Setting up Backend"
cd /opt/scrob/backend
$STD uv sync --frozen --no-dev --python 3.12
$STD /opt/scrob/backend/.venv/bin/python -m alembic upgrade head
msg_ok "Set up Backend"

msg_info "Building Frontend"
cd /opt/scrob/frontend
$STD npm ci
$STD npm run build
msg_ok "Built Frontend"

msg_info "Creating Services"
cat <<EOF >/etc/systemd/system/scrob-backend.service
[Unit]
Description=Scrob Backend
After=network.target postgresql.service
Requires=postgresql.service

[Service]
Type=simple
User=root
WorkingDirectory=/opt/scrob/backend
EnvironmentFile=/opt/scrob/.env
ExecStart=/opt/scrob/backend/.venv/bin/uvicorn main:app --host 127.0.0.1 --port 7331
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF >/etc/systemd/system/scrob-frontend.service
[Unit]
Description=Scrob Frontend
After=network.target scrob-backend.service
Requires=scrob-backend.service

[Service]
Type=simple
User=root
WorkingDirectory=/opt/scrob/frontend
Environment=HOST=0.0.0.0
Environment=PORT=7330
ExecStart=/usr/bin/node /opt/scrob/frontend/dist/server/entry.mjs
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now scrob-backend scrob-frontend
msg_ok "Created Services"

motd_ssh
customize
cleanup_lxc
