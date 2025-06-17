
# Step 3 — Install Services

---

## Prerequisites

- Access to ThingsBoard Cloud (device token)  
- (Already installed if steps were followed correctly)

| Package                      | Purpose                                             | Install Command                                      |
|-----------------------------|-----------------------------------------------------|------------------------------------------------------|
| **Python 3.8 + pip**        | Runs telemetry scripts                              | `sudo apt install -y python3 python3-venv`           |
| **xserver-xorg-video-dummy**| Real X server on `:1` without GPU / monitor         | `sudo apt install -y xserver-xorg-video-dummy`       |
| **xdotool**                 | Sends <kbd>Ctrl + L</kbd> inside the hidden window  | `sudo apt install -y xdotool`                        |

---

## 1.1 Prepare the `.env` File

```bash
nano ~/tango_remote_server/send_to_tb/.env
```

Paste the following (with the correct device token):

```ini
###############################################################################
# ▶︎ Credentials
###############################################################################
# ThingsBoard device token (unique par device)
DEVICE_TOKEN=UuGa6uD0YW31ElEjxmEo

###############################################################################
# ▶︎ Paths
###############################################################################
# Path to the SQLite database (via Wine)
DB_PATH=~/.wine/drive_c/ProgramData/Full Gauge/Sitrad/data.db
# Name of the log file (created under logs/)
LOG_FILE=sitrad_push.log

###############################################################################
# ▶︎ Telemetry sending behavior
###############################################################################
# Max number of lines per batch allowed
MAX_BATCH_SIZE=25
# Max retry attempts before giving up (resilient split logic included)
MAX_RETRY=5
# Initial backoff (in milliseconds) before first retry
INITIAL_DELAY_MS=200
# Max delay before giving up (resilient split logic included)
MAX_DELAY_SEC=30
# Timeout (in seconds) for each HTTP POST request
POST_TIMEOUT=10
# Enforce a fixed time window (in seconds) between each batch
BATCH_WINDOW_SEC=2.0
# Minimum size for batch splitting (disable split with large value like 9999)
MIN_BATCH_SIZE_TO_SPLIT=1

###############################################################################
# ▶︎ Filtering / Data cleaning
###############################################################################
# Ignore any row with a timestamp older than this value (UTC, in ms) -- 2000-01-01 UTC
MIN_VALID_TS_MS=946684800000
# Sqlite timeout in sec
SQLITE_TIMEOUT_SEC=30

###############################################################################
# ▶︎ Table names
###############################################################################
TELEMETRY_TABLE=tc900log
ALARM_TABLE=rel_alarmes

###############################################################################
# ▶︎ Logging
###############################################################################
# DEBUG | INFO | WARNING | ERROR
LOG_LEVEL=DEBUG
# Delete logs older than X days automatically
PURGE_LOG_DAYS=1
```

Then exit nano:
```bash
Ctrl+X → Y → Enter
```

-> `DB_PATH` accepts `~` or full path. `LOG_FILE` is written under `send_to_tb/logs/`.

---

## 1.2 Make Scripts Executable

```bash
cd ~/tango_remote_server/

chmod +x send_to_tb/main.py
chmod +x scripts/sitrad/setup_sitrad.sh
chmod +x scripts/sitrad/send_ctrl_l_to_sitrad.sh
chmod +x scripts/setup_bash/setup_services.sh
chmod +x scripts/setup_bash/kill_services.sh
```

---

## 1.3 Automatic Execution

### Install Services

```bash
./scripts/setup_bash/setup_services.sh
```

This sets up and enables:

| Unit                    | Description                                            |
|-------------------------|--------------------------------------------------------|
| `display.service`       | Starts Xorg (`:1`) with dummy driver                   |
| `sitrad.service`        | Launches Wine + Sitrad (requires `display.service`)    |
| `send_to_tb.timer`      | Triggers `send_to_tb.service` every 30 seconds         |
| `send_to_tb.service`    | Runs `main.py` once with `.env` config                 |
| `journald` drop-in      | Limits logs to 200 MiB / 7 days                        |

### Uninstall Services

```bash
./scripts/setup_bash/kill_services.sh
```

Disables all units, removes configs, and stops lingering processes.

---

## 1.4 On First Execution

Connect a monitor and RS-485 USB adapter.

Launch Sitrad:

```bash
./scripts/setup_bash/kill_services.sh
sitrad4.13
```

Then:

1. Go to *Configuration* → enable **COM1** only  
2. Communication → Search  
3. When instrument appears, close  
4. Communication → Start  
5. Exit Sitrad
6. Restart services

```bash
./scripts/setup_bash/setup_services.sh
```
 
7. Reboot:

```bash
sudo reboot
```

---

Having issues? → [Troubleshooting](troubleshooting.md).

---
