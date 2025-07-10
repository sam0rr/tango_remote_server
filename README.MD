# README

---

## Project Description

---

This repository turns a Linux ARM64 box (Radxa zero 3W, etc.) into a self-contained server that :

1. **Runs Sitrad 4.13** under Wine (Hangover more performant) – completely head-less, thanks to a **dummy Xorg server**.
2. **Harvests telemetry** from the SQLite database Sitrad produces.
3. **Sends the data** to **ThingsBoard Cloud** through a resilient HTTP client with rate-limiting,
   auto-retry, and batching.
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
│   ├── base_guide.md                     ← High-level overview & “Complete Guide”
│   └── components/
│       ├── complete_installation/        ← End-to-end install steps
│       │   ├── install_dependencies.md
│       │   ├── install_services.md
│       │   ├── install_sitrad.md
│       │   └── troubleshooting.md
│       │
│       └── setup_image/                  ← Image-creation & clone procedures
│           ├── create_image.md
│           ├── prepare_image.md
│           ├── prepare_image.md
│           └── first_boot_image.md
│
├── scripts/
│   ├── setup_bash/
│   │   ├── kill_services.sh              ← Stops & cleans up user services
│   │   ├── prepare_image.sh              ← Prepares clonable SD-card image
│   │   └── setup_services.sh             ← Installs per-user systemd units
│   │
│   ├── sitrad/
│   │   ├── send_ctrl_l_to_sitrad.sh      ← Send Ctrl+L after Sitrad loads
│   │   └── setup_sitrad.sh               ← Launches Wine + Sitrad under dummy X
│   │ 
│   └── watchdog/
│       └── watchdog.sh                   ← Watchdog for Sitrad health
│
├── send_to_tb/
│   ├── main.py                           ← Entry-point for telemetry exporter
│   ├── .env                              ← You fill in your ThingsBoard token, etc.
│   │
│   ├── clients/
│   │   ├── __init__.py
│   │   ├── http_client.py                ← Robust HTTP with rate-limit & retry
│   │   └── thingsboard_client.py         ← ThingsBoard-specific wrapper
│   │
│   ├── fetchers/
│   │   ├── __init__.py
│   │   ├── data_fetcher.py               ← Base DataFetcher interface
│   │   └── sitrad_data_fetcher.py        ← SQLite-DB polling implementation
│   │
│   ├── launcher/
│   │   ├── __init__.py
│   │   └── send_launcher.py              ← Batching & dispatch orchestration
│   │
│   └── utils/
│       ├── __init__.py
│       ├── config.py                     ← Loads & validates `.env`
│       │
│       ├── db/
│       │   ├── db_cleaner.py             ← Purges sent rows
│       │   ├── db_connect.py             ← `get_sqlite_connection()`
│       │   └── db_schema_manager.py      ← Ensure telemetry time column & trigger
│       │
│       └── log/
│           ├── log_setup.py              ← Configures Python logs
│           └── log_cleaner.py            ← Trims old log files
│
├── .gitignore
└── README.md                             ← You are here!
```

---

## Extension Possibilities

- Add a new `DataFetcher` (e.g., MySQL, API, CSV) by subclassing `DataFetcher`.  
- Add a new `HttpClient` (e.g., Kafka, another IoT API) by subclassing `HttpClient`.  
- The core `SendToLauncher` logic remains unchanged.  

---

# Installation & Configuration Guide

Follow the full setup guide here: **[Complete Guide](docs/base_guide.md)**.

---
