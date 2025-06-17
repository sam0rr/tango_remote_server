
# Installation & Configuration Guide

---

## Clone the Repository

Open a terminal on your Raspberry Pi and run:

```bash
git clone https://github.com/sam0rr/tango_remote_server
cd tango_remote_server
```

---

## Installation Steps Overview

This guide provides a high‑level overview. Each major step links to a dedicated document located in  
`docs/components/`.

| Step | Document |
|------|----------|
| 1. Install OS dependencies      | [install_dependencies.md](components/install_dependencies.md) |
| 2. Install Wine 32‑bit & Sitrad | [install_sitrad.md](components/install_sitrad.md)             |
| 3. Deploy systemd services      | [install_services.md](components/install_services.md)         |
| 4. Troubleshooting & FAQ        | [troubleshooting.md](components/troubleshooting.md)           |

---

## Hardware Prerequisites

- Raspberry Pi 4 or any ARM64-based Linux board  
- SIM7600X‑H 4G LTE HAT (USB)
- RS-485 USB converter connected to a free USB port
- Full Gauge TC-900 connected to the RS-485 converter
- Active data SIM for your 4G HAT

---
