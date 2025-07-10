
# Installation & Configuration Guide

---

## Clone the Repository

Open a terminal on your machine and run:

```bash
git clone https://github.com/sam0rr/tango_remote_server
cd tango_remote_server
```

---

## Complete Installation Steps Overview

| Step                            | Document                                                                                   |
| ------------------------------- | -------------------------------------------------------------------------------------------|
| 1. Install OS dependencies      | [install\_dependencies.md](/docs/components/complete_installation/install_dependencies.md) |
| 2. Install Wine & Sitrad        | [install\_sitrad.md](/docs/components/complete_installation/install_sitrad.md)             |
| 3. Deploy systemd services      | [install\_services.md](/docs/components/complete_installation/install_services.md)         |
| 4. Troubleshooting & FAQ        | [troubleshooting.md](/docs/components/complete_installation/troubleshooting.md)            |

---

## Setup And Clone Image Steps Overview

| Step                           | Document                                                                  |
| ------------------------------ | --------------------------------------------------------------------------|
| 1. Prepare image for cloning   | [prepare\_image.md](/docs/components/setup_image/prepare_image.md)        |
| 2. Create SD-card image        | [create\_image.md](/docs/components/setup_image/create_image.md)          |
| 3. Clone image on SD-card      | [clone\_image.md](/docs/components/setup_image/clone_image.md)            |
| 4. First-boot setup steps      | [first\_boot\_image.md](/docs/components/setup_image/first_boot_image.md) |

---

## Hardware Prerequisites

* Orange/Radxa zero 2w 4gb or any ARM64-based Linux board
* 4G LTE HAT (USB)
* RS-485 USB converter connected to a free USB port
* Full Gauge TC-900 connected to the RS-485 converter
* Active data SIM for your 4G HAT

---
