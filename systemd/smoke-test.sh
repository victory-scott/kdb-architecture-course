#!/usr/bin/env bash
set -euo pipefail

echo "== kx-tpstack smoke test =="

# Require systemd (Linux). macOS uses launchd and won't work here.
if ! command -v systemctl >/dev/null 2>&1; then
  echo "Error: systemctl not found. This smoke test requires Linux user services."
  echo "Tip: On macOS, use the manual Quickstart in README.md to run q processes directly."
  exit 1
fi

CONF_DIR="${HOME}/.config/kxtpstack"
ENV_FILE="${CONF_DIR}/common.env"
REPO_DIR="${REPO_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Creating default env at $ENV_FILE"
  mkdir -p "$(dirname "$ENV_FILE")" "$CONF_DIR"
  cp "$REPO_DIR/systemd/common.env" "$ENV_FILE"
fi

source "$ENV_FILE"

# assert all the necessary env properties are set
for var in QBIN APP_DIR HDB_DIR TP_PORT RDB_PORT HDB_PORT GW_PORT; do
  if [[ -z "${!var:-}" ]]; then
    echo "Error: Required environment variable $var is not set"
    exit 1
  fi
done

echo "Using QBIN=$QBIN APP_DIR=$APP_DIR"
mkdir -p "$HDB_DIR"

echo "Linking units"
systemctl --user link "$REPO_DIR/systemd/kx-tp.service" \
                        "$REPO_DIR/systemd/kx-rdb.service" \
                        "$REPO_DIR/systemd/kx-hdb.service" \
                        "$REPO_DIR/systemd/kx-gw.service" \
                        "$REPO_DIR/systemd/kx-tpstack.target" >/dev/null
systemctl --user daemon-reload

echo "Starting stack target"
systemctl --user start kx-tpstack.target

echo "Waiting for readiness logs (30s timeout)"
if command -v timeout >/dev/null 2>&1; then
  timeout 30 bash -c '
    until journalctl --user -o cat -n 200 \
        -u kx-tp.service -u kx-rdb.service -u kx-hdb.service -u kx-gw.service \
        | grep -qE "(TP|RDB|HDB|GW) ready on port"; do sleep 1; done'
else
  SECS=30; ok=0
  for i in $(seq 1 $SECS); do
    if journalctl --user -o cat -n 200 \
        -u kx-tp.service -u kx-rdb.service -u kx-hdb.service -u kx-gw.service \
        | grep -qE "(TP|RDB|HDB|GW) ready on port"; then ok=1; break; fi
    sleep 1
  done
  if [[ $ok -ne 1 ]]; then
    echo "Timed out waiting for readiness logs"
    exit 1
  fi
fi

echo "Starting sample feed for 5s"
"$QBIN" "$APP_DIR/tick/feed.q" -tp "$TP_PORT" </dev/null >/tmp/kx-feed.log 2>&1 &
FEED_PID=$!
sleep 5
kill $FEED_PID || true

echo "Querying RDB and GW"
"$QBIN" -q -e "h:hopen $RDB_PORT; -1 \"RDB trade count: \",string h \"count trade\"; \";\"" || true
"$QBIN" -q -e "g:hopen $GW_PORT; show g \"getTradeData[.z.D-1;.z.D;`APPL]\"; \";\"" || true

echo "Done. Use 'journalctl --user -u kx-*.service -f' to inspect logs."
