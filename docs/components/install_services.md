
# Step 3 — Install Services

## Prerequisites

- Access to ThingsBoard Cloud (device token)  
- (Already installed if steps were followed correctly)
| Package                          | Purpose                                             | Debian/RPi Install Command                                   |
|----------------------------------|-----------------------------------------------------|--------------------------------------------------------------|
| **Python 3.8 + pip**             | Runs telemetry scripts                              | `sudo apt install -y python3 python3-venv`                   |
| **xserver-xorg-video-dummy**     | Real X server on `:1` without GPU / monitor         | `sudo apt install -y xserver-xorg-video-dummy`               |
| **xdotool**                      | Sends <kbd>Ctrl + L</kbd> inside the hidden window  | `sudo apt install -y xdotool`                                |

## 1.1 Prepare the `.env` File

In `tango_remote_server/scripts/send_to_tb/.env`:

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

## 1.2 Make Scripts Executable

From `tango_remote_server/scripts/` :

```bash
chmod +x send_to_tb/main.py
chmod +x sitrad/setup_sitrad.sh
chmod +x sitrad/send_ctrl_l_to_sitrad.sh
chmod +x setup_bash/setup_services.sh
chmod +x setup_bash/kill_services.sh
```

## 1.3 Automatic Execution

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

### Uninstall Services

```bash
./scripts/setup_bash/kill_services.sh
```

Deletes units, Xorg dummy config, journald retention file, disables linger.

## 1.4 On First Execution

Plug in a monitor and your RS-485 adapter.

Launch Sitrad manually:

```bash
sitrad4.13
```

Or via GUI: Menu ▸ Run in Terminal.

Once open:

1. Configuration ▸ Enable **COM1** only  
2. Communication ▸ Search for instruments  
3. If found, Close  
4. Communication ▸ Start  
5. Exit the app  
6. Reboot:

```bash
sudo reboot
```

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

### Utils

- `utils/log_cleaner.py`  
  - Deletes `.log` files older than `PURGE_LOG_DAYS`.  
- `utils/db_cleaner.py`  
  - Deletes sent rows from the SQLite `tc900log` table in one transaction.

---

Having any problems? **[Troubleshooting](troubleshooting.md)**.

---