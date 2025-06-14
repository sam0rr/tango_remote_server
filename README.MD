# README

## Project Description

This repository turns a low-cost Linux box (Raspberry Pi 3/4, Debian 12 PC, etc.) into a self-contained
gateway that :

1. **Runs Sitrad 4.13** under Wine – completely head-less, thanks to a **dummy Xorg server** (no
   Xvfb, no window-manager, no HDMI dongle).
2. **Harvests telemetry** from the SQLite database Sitrad produces.
3. **Sends the data** to **ThingsBoard Cloud** through a resilient HTTP client with rate-limiting,
   auto-retry, and fine-grained batching.
4. **Rotates its own logs** as well as `journald`, and restarts automatically via **per-user
   systemd** units.

Everything lives in an ordinary user account; no root daemons are required once installed.

---

## Project Structure

```
tango_remote_server/
├── send_to_tb/
│   ├── main.py                     ← Entrypoint
│   ├── .env                        ← Environment config
│   ├── clients/
│   │   ├── http_client.py
│   │   └── thingsboard_client.py
│   ├── fetchers/
│   │   ├── data_fetcher.py
│   │   └── sitrad_data_fetcher.py
│   ├── launcher/
│   │   └── send_launcher.py
│   ├── utils/
│   │   ├── config.py
│   │   ├── db/
│   │   │   ├── db_cleaner.py       ← Deletes rows after successful sends
│   │   │   └── db_connect.py       ← get_sqlite_connection() helper
│   │   ├── log/
│   │   │   ├── log_setup.py        ← Initializes logging from .env
│   │   │   └── log_cleaner.py      ← Deletes old logs
│   │   └── __init__.py
│   └── __init__.py
├── sitrad/
│   ├── setup_sitrad.sh             ← Launch Wine + Sitrad under xserver-xorg-video-dummy
│   └── send_ctrl_l_to_sitrad.sh    ← Sends Ctrl+L to window after load
├── setup_bash/
│   ├── setup_services.sh           ← Creates systemd services
│   └── kill_services.sh            ← Removes systemd services
├── .gitignore
└── README.md                       ← You're here
```

---

## Prerequisites

- Python 3.7+  
- `requests` and `python-dotenv` (for the Python package)  
- Linux or Raspberry Pi with `systemd --user`  
- Access to ThingsBoard Cloud (device token)  
- SQLite database generated by Sitrad (under Wine)  

## Requirements

| Package                          | Purpose                                             | Debian/RPi Install Command                                    |
|----------------------------------|-----------------------------------------------------|--------------------------------------------------------------|
| **Python 3.8 + pip**             | Runs telemetry scripts                              | `sudo apt install -y python3 python3-venv`                   |
| **xserver-xorg-video-dummy**     | Real X server on `:1` without GPU / monitor         | `sudo apt install -y xserver-xorg-video-dummy`               |
| **xdotool**                      | Sends <kbd>Ctrl + L</kbd> inside the hidden window  | `sudo apt install -y xdotool`                                |
| **systemd --user**               | Already present on Debian & Raspberry Pi OS         | –                                                            |


Install those with:

```bash
sudo apt update
sudo apt install -y python3 python3-venv xdotool xserver-xorg-video-dummy
```

> **No Xvfb, no Openbox**. The dummy driver gives Wine a _real_ X server, which solves focus, font and
> serial-port quirks that Xvfb sometimes causes.
---

## Step-by-Step Installation

### 1. Create and Activate the Virtual Environment

```bash
cd /path/to/scripts
python3 -m venv venv
source venv/bin/activate
```

### 2. Install Python Dependencies

With the virtual environment activated:

```bash
pip install --upgrade pip
pip install requests python-dotenv
```

### 3. Prepare the `.env` File

In `scripts/send_to_tb/.env`:

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

Notes:

- `DB_PATH` can use `~` or an absolute path.  
- `LOG_FILE` is created under `send_to_tb/logs/` at runtime.  

### 4. Make Scripts Executable

From the `scripts/` root:

```bash
chmod +x send_to_tb/main.py
chmod +x sitrad/setup_sitrad.sh
chmod +x sitrad/send_ctrl_l_to_sitrad.sh
chmod +x setup_bash/setup_services.sh
chmod +x setup_bash/kill_services.sh
```

### 5. Manual Execution

Activate the virtual environment:

```bash
source venv/bin/activate
```

#### Run Python data‐sender manually

Option A:

```bash
cd send_to_tb
python main.py
```

Or, if `main.py` is executable:

```bash
./main.py
```

You can check remaining rows with:

```bash
sqlite3 ~/.wine/drive_c/ProgramData/Full\ Gauge/Sitrad/data.db "SELECT COUNT(*) FROM tc900log;"
```

Option B (module style):

```bash
cd scripts
python -m send_to_tb.main
```

#### Run Sitrad 4.13 manually (headless)

```bash
./sitrad/setup_sitrad.sh
```

That will start Sitrad under Wine inside a virtual X server (xserver-xorg-video-dummy on `:1`), then after a short wait send “Ctrl+L” to begin communication.

---

## Automatic Execution On Boot

### Install Services

```bash
./setup_bash/setup_services.sh
```

This creates and enables:

| Unit (user-level)        | Description                                         |
| ------------------------ | --------------------------------------------------- |
| **display.service**      | Launches **Xorg :1** with the dummy driver          |
| **sitrad.service**       | Starts Wine + Sitrad (needs `display.service`)      |
| **send\_to\_tb.timer**   | Fires every **30 s**, spawning `send_to_tb.service` |
| **send\_to\_tb.service** | One-shot Python push (reads `.env`)                 |
| *journald drop-in*       | Keeps system logs ≤ 200 MiB / 7 days                |

### Check Status

```bash
systemctl --user list-timers
journalctl --user -u display.service -f        # Follow Xorg Display logs
journalctl --user -u sitrad.service -f         # Follow Sitrad logs
journalctl --user -u send_to_tb.service -n 50  # Last 50 lines of telemetry‐sender logs
journalctl --disk-usage
```

### Uninstall Services

```bash
./setup_bash/kill_services.sh
```

Deletes units, Xorg dummy config, journald retention file, disables linger.

---

## Launching Sitrad 4.13 (via Wine, headless)

```bash
./sitrad/setup_sitrad.sh
```

- **xserver-xorg-video-dummy** will be started on `:1` (handled by `sitrad.service`).  
- Wine runs Sitrad in that virtual X server (`DISPLAY=:1`).  
- `setup_sitrad.sh` waits for the window, sleeps 45 s until Sitrad’s UI is fully loaded, then calls `send_ctrl_l_to_sitrad.sh` to send “Ctrl+L” inside Xorg.  

If you later connect a physical monitor and want Sitrad to appear on `:0` instead of headless, modify `setup_sitrad.sh` to export `DISPLAY=:0` and remove any Xorg references.

---

## Internal Workings

### 1. `main.py`
1. Load environment variables → `Config.from_env()` (validates and fails fast on missing values).  
2. Instantiate `SitradDataFetcher`.  
3. Instantiate `ThingsBoardClient` (passing `max_delay` in addition to other settings).  
4. Create `SendToLauncher(fetcher, client, max_batch_size, batch_window_sec)` and call `.start()`.

---

### 2. `SitradDataFetcher`
- **`fetch_rows()`**  
  - Open SQLite in WAL mode.  
  - `SELECT * FROM tc900log`.

- **`build_payload(row)`**  
  - Validate the timestamp.  
  - Construct a payload dict containing:  
    - **`rowid`**, **`ts`**  
    - **`values`**: `{ Temp1, Temp2, defr, fans, refr, dig1, dig2 }`

- **`fetch_and_prepare()`**  
  - Iterate `for row in fetch_rows()`:  
    - Call `build_payload(row)`.  
  - Return **list** of all payload dicts.

---

### 3. `ThingsBoardClient`  
*(subclass of `HttpClient`)*  
- Build the POST URL:  
https://thingsboard.cloud/api/v1/{device_token}/telemetry

- **`post_json_with_retry(payloads)`** ← inherited  
- POST JSON with retry/back-off + `Retry-After` handling.  
- **`send_resilient(batch)`** ← inherited  
- Reliably send a batch (split on failures, drop on single-item failure).

---

### 4. `SendToLauncher`
- **`start()`**  
1. Call `_fetch_payloads()` → returns a `List[dict]` of form `{ "rowid":…, "ts":…, "values":{…} }`.  
2. Call `_send_in_chunks(payloads)`.  
3. After all chunks, call `delete_all_rows()` on the alarm table.  
4. Call `client.close()`.

- **`_fetch_payloads()`**  
- `payloads, *_ = fetcher.fetch_and_prepare()`  
- Return `payloads` (ensures we always get the main list).

- **`_send_in_chunks(payloads)`**  
1. Compute `total = len(payloads)`.  
2. For each chunk of size `max_batch_size`:  
   - Use `enumerate(..., start=1)` to get `batch_no`.  
   - Call `_process_batch(chunk, batch_no)`.  
   - Sleep `batch_window_sec` seconds.  

- **`_process_batch(batch, batch_no)`**  
1. `sent = client.send_resilient(batch)`.  
2. If `sent == len(batch)`, call `_delete_batch_rowids(batch)`.  
3. Log: `Batch {batch_no}: sent {sent}/{len(batch)}`.

- **`_delete_batch_rowids(batch)`**  
- Extract `rowid` values from each entry.  
- Call `delete_rows(db_path, telemetry_table, rowids, timeout)` once per batch.

---

## Headless Sitrad Utilities

### `setup_sitrad.sh`

- Detects the FTDI adapter and maps it to COM1 in Wine’s `dosdevices`.  
- Blocks COM2–COM20 by creating dummy directories.  
- Adds `alias sitrad4.13='wine "<...>/SitradLocal.exe"'` to `~/.bashrc`.  
- Exports `DISPLAY=:1` (pointing to Xorg).  
- Starts Wine with Sitrad in the background.  
- Loops until `xdotool search` finds the “Sitrad Local” window in Xorg.  
- Sleeps 45 seconds for UI initialization.  
- Calls `send_ctrl_l_to_sitrad.sh` to send “Ctrl+L” inside Xorg.

### `send_ctrl_l_to_sitrad.sh`

- Verifies that `DISPLAY` is set and looks like X11.  
- Uses `xdotool search --name "Sitrad Local"` to find the Wine window (in Xorg).  
- Sends `Ctrl+L` directly into that window via `xdotool key --window <WID> ctrl+l`.  
- Exits with an error if the window cannot be found or controlled.

---

## Utils

- `utils/log_cleaner.py`  
  - Deletes `.log` files older than `PURGE_LOG_DAYS`.  
- `utils/db_cleaner.py`  
  - Deletes sent rows from the SQLite `tc900log` table in one transaction.

---

## FAQ

**Q: How do I verify that rows were removed?**

```bash
sudo apt install -y sqlite3    # If not installed (READ database)
sqlite3 ~/.wine/drive_c/ProgramData/Full\ Gauge/Sitrad/data.db "SELECT COUNT(*) FROM tc900log;"
```

**Q: How do I check if the script is running?**

```bash
systemctl --user list-timers
```

**Q: How do I view the send logs?**

```bash
journalctl --user -u display.service -f        # Follow Xorg Display logs
journalctl --user -u sitrad.service -f         # Follow Sitrad logs
journalctl --user -u send_to_tb.service -n 50  # Last 50 lines of telemetry‐sender logs
journalctl --disk-usage
```

**Q: Where should I run `chmod +x`?**

```bash
chmod +x send_to_tb/main.py
chmod +x sitrad/setup_sitrad.sh
chmod +x sitrad/send_ctrl_l_to_sitrad.sh
chmod +x setup_bash/setup_services.sh
chmod +x setup_bash/kill_services.sh
```

**Q: How can I test without actually sending data?**

Temporarily set:

```ini
MAX_MSGS_PER_SEC=0
```

Or comment out `send_resilient(...)` calls in the code.

**Q: How is `~` in `DB_PATH` handled?**

It’s expanded automatically via `os.path.expanduser()`.

**Q: Should I commit `venv/` to version control?**

No—add it to your `.gitignore`.

---

## Extension Possibilities

- Add a new `DataFetcher` (e.g., MySQL, API, CSV) by subclassing `DataFetcher`.  
- Add a new `HttpClient` (e.g., Kafka, another IoT API) by subclassing `HttpClient`.  
- The core `SendToLauncher` logic remains source/destination agnostic.

---

With this updated README, you can:
- Initialize a Python virtual environment.  
- Install dependencies (including `Xorg Dumm` and `xdotool` for headless Sitrad).  
- Make scripts executable.  
- Run `send_to_tb` manually or via systemd timer.  
- Run Sitrad 4.13 under Wine in a headless X server (Xorg), with automatic “Ctrl+L” after UI load.  
- Monitor emissions to ThingsBoard.  
- Adjust file paths and DISPLAY settings as needed for your environment.
