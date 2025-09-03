#!/usr/bin/env bash
set -euo pipefail

# Installs kdb+ tick systemd units, env, and app files
# Defaults (override via env):
#  APP_DIR=/opt/kx/tick
#  CFG_FILE=/etc/kx/tick.env
#  DATA_DIR=/var/lib/kx/tick
#  USE_KDB_USER=0 (set to 1 to run services as 'kdb' via drop-ins)
#  ENABLE=0 START=0

APP_DIR=${APP_DIR:-/opt/kx/tick}
CFG_FILE=${CFG_FILE:-/etc/kx/tick.env}
DATA_DIR=${DATA_DIR:-/var/lib/kx/tick}
USE_KDB_USER=${USE_KDB_USER:-0}
ENABLE=${ENABLE:-0}
START=${START:-0}

if [[ $EUID -ne 0 ]]; then
  echo "Please run as root (sudo)" >&2
  exit 1
fi

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
UNIT_DIR=/etc/systemd/system

echo "Installing app to: ${APP_DIR}"
install -d -m 0755 "${APP_DIR}"
install -d -m 0755 "${APP_DIR}/tick"

echo "Copying q sources (tick.q, tick/*.q)"
install -m 0644 "${ROOT_DIR}/tick.q" "${APP_DIR}/"
install -m 0644 "${ROOT_DIR}/tick/"*.q "${APP_DIR}/tick/"

echo "Creating data directories: ${DATA_DIR} and ${DATA_DIR}/sym"
install -d -m 0755 "${DATA_DIR}" "${DATA_DIR}/sym"

echo "Installing environment: ${CFG_FILE}"
install -d -m 0755 "$(dirname "${CFG_FILE}")"
if [[ -f "${CFG_FILE}" ]]; then
  echo "Config exists, leaving as-is: ${CFG_FILE}"
else
  install -m 0644 "${ROOT_DIR}/systemd/tick.env" "${CFG_FILE}"
fi

echo "Installing units to ${UNIT_DIR}"
install -m 0644 "${ROOT_DIR}/systemd/"kx-*.service "${UNIT_DIR}/"
install -m 0644 "${ROOT_DIR}/systemd/kx-stack.target" "${UNIT_DIR}/"

if [[ "${USE_KDB_USER}" == "1" ]]; then
  echo "Ensuring service user 'kdb' exists (system account)"
  id kdb >/dev/null 2>&1 || useradd -r -s /usr/sbin/nologin kdb
  echo "Setting ownership for app/data to kdb:kdb"
  chown -R kdb:kdb "${APP_DIR}" "${DATA_DIR}"
  echo "Writing drop-in overrides to run as kdb"
  for u in kx-tp kx-rdb kx-hdb kx-rts kx-cep kx-gw kx-feed; do
    odir="${UNIT_DIR}/${u}.service.d"
    install -d -m 0755 "${odir}"
    cat >"${odir}/override.conf" <<EOF
[Service]
User=kdb
Group=kdb
EOF
  done
fi

echo "Reloading systemd"
systemctl daemon-reload

if [[ "${ENABLE}" == "1" ]]; then
  echo "Enabling kx-stack.target"
  systemctl enable kx-stack.target
fi

if [[ "${START}" == "1" ]]; then
  echo "Starting kx-stack.target"
  systemctl start kx-stack.target
fi

echo "Install complete. Next steps:"
echo "- Edit ${CFG_FILE} to set Q_BIN, APP_DIR (${APP_DIR}), TP_LOG_DIR (${DATA_DIR}), HDB_DIR (${DATA_DIR}/sym)"
echo "- systemctl daemon-reload"
echo "- systemctl enable kx-stack.target"
echo "- systemctl start kx-stack.target"

