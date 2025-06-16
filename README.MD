# README

---

## Project Description

---

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
TANGO_REMOTE_SERVER/
├── assets/
│   └── SetupLocal.exe
│
├── docs/
│   ├── components/
│   │   ├── _images/
│   │   │   ├── install_dependencies_images/
│   │   │   ├── install_services_images/
│   │   │   ├── install_sitrad_images/
│   │   │   ├── troubleshooting_images/
│   │   ├── install_dependencies.md
│   │   ├── install_services.md
│   │   ├── install_sitrad.md
│   │   └── troubleshooting.md
│   └── install_guide.md
│
├── scripts/
│   ├── setup_bash/
│   │   ├── kill_services.sh              ← Removes systemd services
│   │   └── setup_services.sh             ← Creates systemd services
│   ├── sitrad/
│   │   ├── send_ctrl_l_to_sitrad.sh      ← Sends Ctrl+L to window after load
│   │   └── setup_sitrad.sh               ← Launch Wine + Sitrad under xserver-xorg-video-dummy
│
├── send_to_tb/
│   ├── main.py                           ← Entrypoint
│   ├── .env                              ← Environment config (you need to implement)
│   ├── clients/
│   │   ├── __init__.py
│   │   ├── http_client.py
│   │   └── thingsboard_client.py
│   ├── fetchers/
│   │   ├── __init__.py
│   │   ├── data_fetcher.py
│   │   └── sitrad_data_fetcher.py
│   ├── launcher/
│   │   ├── __init__.py
│   │   └── send_launcher.py
│   ├── utils/
│   │   ├── __init__.py
│   │   ├── config.py
│   │   ├── db/
│   │   │   ├── db_cleaner.py             ← Deletes rows after successful sends
│   │   │   └── db_connect.py             ← get_sqlite_connection() helper
│   │   └── log/
│   │       ├── log_setup.py              ← Initializes logging from .env
│   │       └── log_cleaner.py            ← Deletes old logs
│   └── __init__.py
│
├── .gitignore
└── README.md                             ← You're here

```

---

## Extension Possibilities

- Add a new `DataFetcher` (e.g., MySQL, API, CSV) by subclassing `DataFetcher`.  
- Add a new `HttpClient` (e.g., Kafka, another IoT API) by subclassing `HttpClient`.  
- The core `SendToLauncher` logic remains unchanged.  

---

# Installation & Configuration Guide

Follow the full setup guide here: **[Installation Guide](docs/install_guide.md)**

---
