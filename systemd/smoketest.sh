#!/usr/bin/env bash
set -euo pipefail

# Basic smoke test for kdb+ tick systemd stack

CFG_FILE=${CFG_FILE:-/etc/kx/tick.env}
GW_PORT_DEFAULT=5014
RDB_PORT_DEFAULT=5011
TP_PORT_DEFAULT=5010

if [[ $EUID -ne 0 ]]; then
  echo "Note: running without sudo; will not start/stop units."
fi

have() { command -v "$1" >/dev/null 2>&1; }

start_if_inactive() {
  local unit=$1
  if systemctl is-active --quiet "$unit"; then
    echo "OK: $unit is active"
  else
    echo "Starting $unit"
    sudo systemctl start "$unit"
    sleep 2
    systemctl is-active --quiet "$unit" && echo "OK: $unit is active" || { echo "FAIL: $unit failed to start"; exit 1; }
  fi
}

echo "Loading config: ${CFG_FILE}"
if [[ -f "${CFG_FILE}" ]]; then
  # shellcheck disable=SC1090
  . "${CFG_FILE}"
else
  echo "WARN: ${CFG_FILE} not found; using default ports"
fi

TP_PORT=${TP_PORT:-$TP_PORT_DEFAULT}
RDB_PORT=${RDB_PORT:-$RDB_PORT_DEFAULT}
GW_PORT=${GW_PORT:-$GW_PORT_DEFAULT}

echo "Ensuring core units are running"
start_if_inactive kx-tp.service
start_if_inactive kx-hdb.service
start_if_inactive kx-rdb.service

echo "Starting subscribers, gateway, and feed"
start_if_inactive kx-rts.service
start_if_inactive kx-cep.service
start_if_inactive kx-gw.service
start_if_inactive kx-feed.service

echo "Checking listening ports"
if have ss; then
  ss -ltn | awk 'NR==1||/:501[0-9]/'
elif have netstat; then
  netstat -ltn | awk 'NR==2||/:501[0-9]/'
else
  echo "WARN: ss/netstat not available; skipping port check"
fi

qclient() {
  local port=$1
  local cmd=$2
  if [[ -n "${Q_BIN:-}" && -x "${Q_BIN}" ]]; then
    printf "%s\n" "$cmd" | "${Q_BIN}" ":${port}" -q 2>&1
  elif have q; then
    printf "%s\n" "$cmd" | q ":${port}" -q 2>&1
  else
    echo "WARN: q client not found; skipping query against :${port}"; return 0
  fi
}

echo "Probing RDB (:${RDB_PORT}) tables[]"
qclient "${RDB_PORT}" 'value tables[]' || true

echo "Probing GW (:${GW_PORT}) with getTradeData (may be empty early)"
qclient "${GW_PORT}" 'getTradeData[.z.D-1;.z.D;`APPL]' || true

echo "Smoke test complete. Review output above and journal logs if needed:"
echo "  sudo journalctl -u kx-*.service -b"

