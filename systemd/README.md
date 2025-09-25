## KX Tickerplant Stack — systemd

This directory contains user-level systemd units to run the kdb+ tick stack (tickerplant, RDB, HDB, and gateway) with ports driven by environment variables.

### Units
- `kx-tp.service`: Tickerplant (`tick.q`). Listens on `TP_PORT`.
- `kx-rdb.service`: Realtime database (`tick/rdb.q`). Listens on `RDB_PORT`, connects to TP on `TP_PORT`.
- `kx-hdb.service`: Historical database (`tick/hdb.q`). Listens on `HDB_PORT`.
- `kx-gw.service`: Gateway (`tick/gw.q`). Listens on `GW_PORT`, connects to RDB/HDB.
- `kx-tpstack.target`: Convenience target grouping the above.

### Environment configuration
- Unit files read: `%h/.config/kxtpstack/common.env`
- A sample is provided at `systemd/common.env`. Copy it to your user config directory and adjust as needed:

```bash
mkdir -p ~/.config/kxtpstack
cp systemd/common.env ~/.config/kxtpstack/common.env
# edit ports/paths if desired: TP_PORT, RDB_PORT, HDB_PORT, GW_PORT, HDB_DIR
mkdir -p "$HOME/kx-hdb"   # default HDB_DIR
```

Variables
- `QBIN`: Path to `q` binary (default `/opt/kx/q`).
- `APP_DIR`: Root with `tick.q` and `tick/*.q`.
- `TP_PORT`, `RDB_PORT`, `HDB_PORT`, `GW_PORT`: Service ports (peers are passed as ports; localhost assumed).
- `HDB_DIR`: Filesystem directory for the mounted HDB (must be writable).
- `QOPTS`: Extra flags to pass to all q apps (optional).

### Linking units (user services)
These are intended as user services. Use `systemctl --user` and link units directly from the repo without copying:

```bash
systemctl --user link $(pwd)/systemd/kx-tp.service
systemctl --user link $(pwd)/systemd/kx-rdb.service
systemctl --user link $(pwd)/systemd/kx-hdb.service
systemctl --user link $(pwd)/systemd/kx-gw.service
systemctl --user link $(pwd)/systemd/kx-tpstack.target
systemctl --user daemon-reload
```

### Bring up the stack
Start all services via the target, or start individually:

```bash
# Start all (target pulls in tp, rdb, hdb, gw)
systemctl --user start kx-tpstack.target

# Or start individually
systemctl --user start kx-tp.service kx-rdb.service kx-hdb.service kx-gw.service
```

Enable for autostart on login:

```bash
systemctl --user enable kx-tp.service kx-rdb.service kx-hdb.service kx-gw.service
```

Optionally enable the target:

```bash
systemctl --user enable kx-tpstack.target
```

### Restart and stop
- Restart a single service:

```bash
systemctl --user restart kx-tp.service
systemctl --user restart kx-rdb.service
systemctl --user restart kx-hdb.service
systemctl --user restart kx-gw.service
```

- Stop all:

```bash
systemctl --user stop kx-gw.service
systemctl --user stop kx-hdb.service
systemctl --user stop kx-rdb.service
systemctl --user stop kx-tp.service
# or: stop via the target
systemctl --user stop kx-tpstack.target

```

### Quickstart test
1) Copy env and link units

```bash
mkdir -p ~/.config/kxtpstack
cp systemd/common.env ~/.config/kxtpstack/common.env
systemctl --user link $(pwd)/systemd/kx-tp.service \
                       $(pwd)/systemd/kx-rdb.service \
                       $(pwd)/systemd/kx-hdb.service \
                       $(pwd)/systemd/kx-gw.service \
                       $(pwd)/systemd/kx-tpstack.target
systemctl --user daemon-reload
```

2) Start the stack and watch logs

```bash
systemctl --user start kx-tpstack.target
journalctl --user -u kx-tp.service -u kx-rdb.service -u kx-hdb.service -u kx-gw.service -f
# Expect to see: "TP/RDB/HDB/GW ready on port ..."
```

3) Generate sample data and query via RDB/GW

In a separate terminal, start the sample feed (publishes trades/quotes):

```bash
q tick/feed.q -tp 5010
```

Then, in another terminal, verify data in RDB and query via GW:

```bash
# From RDB: verify rows landed
q -q -e "h:hopen 5011; -1 \"RDB trade count: \",string h \"count trade\"; \";\""

# From GW: get latest APPL trade across RDB/HDB
q -q -e "g:hopen 5014; show g \"getTradeData[.z.D-1;.z.D;`APPL]\"; \";\""
```

### Check status and logs
- Status:

```bash
systemctl --user status kx-tp.service
systemctl --user status kx-rdb.service
systemctl --user status kx-hdb.service
systemctl --user status kx-gw.service
```

- Live logs (press Ctrl+C to exit):

```bash
journalctl --user -u kx-tp.service -f
journalctl --user -u kx-rdb.service -f
journalctl --user -u kx-hdb.service -f
journalctl --user -u kx-gw.service -f
```

### Update configuration
After editing unit files or `common.env`:

```bash
systemctl --user daemon-reload
systemctl --user restart kx-tp.service kx-rdb.service kx-hdb.service kx-gw.service
```

### Cleanup
Stop and disable services, unlink units:

```bash
systemctl --user stop kx-gw.service kx-hdb.service kx-rdb.service kx-tp.service
systemctl --user disable kx-gw.service kx-hdb.service kx-rdb.service kx-tp.service

systemctl --user disable kx-tpstack.target 2>/dev/null || true
systemctl --user stop kx-tpstack.target 2>/dev/null || true

systemctl --user reset-failed
systemctl --user unlink $(pwd)/systemd/kx-gw.service
systemctl --user unlink $(pwd)/systemd/kx-hdb.service
systemctl --user unlink $(pwd)/systemd/kx-rdb.service
systemctl --user unlink $(pwd)/systemd/kx-tp.service
systemctl --user unlink $(pwd)/systemd/kx-tpstack.target
systemctl --user daemon-reload
```

### Troubleshooting
- Ensure `~/.config/kxtpstack/common.env` exists and has correct `APP_DIR` and ports.
- The q binary path (`QBIN`) must be correct and accessible.
