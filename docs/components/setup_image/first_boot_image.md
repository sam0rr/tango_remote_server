
# Step 4 — First Boot on New SD Card

---

## 4.1 Boot the target device
Insert the SD card into the Raspberry Pi (or ARM64 board) and power it on.

---

## 4.2 Reconnect Tailscale (with SSH)

Give your machine a unique hostname (to avoid name collisions on Tailscale):
```bash
sudo hostnamectl set-hostname <your_device_name>
sudo tailscale up --ssh
```

---

## 4.3 Update the real device token

```bash
nano ~/tango_remote_server/send_to_tb/.env
```

Replace the placeholder with your actual token:

```ini
DEVICE_TOKEN=<your_actual_device_token>
```

Then exit nano:
```bash
Ctrl+X → Y → Enter
```

---

## 4.4 Start all services & reboot

```bash
cd ~/tango_remote_server
./scripts/setup_bash/setup_services.sh
sudo reboot
```

---

Return to **[Complete Guide](/docs/base_guide.md)** to continue.

---
