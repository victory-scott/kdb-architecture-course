# Systemd units for kdb+ tick stack

This directory provides example `systemd` units to manage the example kdb+ tickerplant stack.

Services:
- kx-tp.service — tickerplant (log + publish)
- kx-rdb.service — in-memory real-time DB
- kx-hdb.service — historical DB mount
- kx-rts.service — simple real-time subscriber
- kx-cep.service — stats subscriber
- kx-gw.service — gateway (queries RDB/HDB)
- kx-feed.service — demo feed generator
- kx-stack.target — convenience target to start/stop the whole stack

## Quick Start
- Install env, app files, and units:
  - `sudo bash systemd/install.sh`
  - Options: `USE_KDB_USER=1` to run as `kdb`, `ENABLE=1 START=1` to enable/start the stack
- Smoke test: `bash systemd/smoketest.sh`

## What the scripts do
- `install.sh`:
  - Copies q sources (`tick.q`, `tick/*.q`) to `/opt/kx/tick` (override with `APP_DIR`)
  - Installs env to `/etc/kx/tick.env` if absent
  - Installs units and `kx-stack.target` to `/etc/systemd/system`
  - Optionally creates/runs as `kdb` (`USE_KDB_USER=1` drop-ins)
  - Reloads systemd; can enable/start the stack
- `smoketest.sh`:
  - Starts units if inactive
  - Checks listening ports
  - Optionally probes RDB and GW with q if available

## Notes
- Units use `EnvironmentFile=/etc/kx/tick.env` and `WorkingDirectory=${APP_DIR}` (default `/opt/kx/tick`).
- Data directories default to `/var/lib/kx/tick` (TP log) and `/var/lib/kx/tick/sym` (HDB root).
- Some scripts hardcode peer ports (TP/RDB/HDB). Adjust the q scripts if you need remote addresses.

## Ordering
- RDB requires the tickerplant.
- Gateway requires RDB and HDB.
- Feed/CEP/RTS require the tickerplant.
