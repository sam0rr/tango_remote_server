
# Step 4 — First Boot on New SD Card

---

## 4.1 Boot the target device

Insert the SD card into the Raspberry Pi (or ARM64 board) and power it on.

---

## 4.2 Optional: Boot from eMMC (only if your board has eMMC storage)

If your device can use eMMC instead the SD card, follow these steps. Otherwise, skip directly to **4.3 Reconnect Tailscale**.

1. Open a terminal and launch the Armbian configuration utility:

   ```bash
   sudo armbian-config
   ```
2. Navigate through the menu:

   * **System**
   * **Storage**
   * **Install**
   * **2 - Boot from eMMC - System on eMMC**
   * **1 - ext4**
3. Wait for the installation to finish. The system will automatically shut down when complete.
4. Remove the SD card from the board.
5. Power on your device again (no need SD card inserted at this point).

---

## 4.3 Reconnect Tailscale (with SSH)

Assign a unique hostname to avoid collisions on Tailscale:

```bash
sudo hostnamectl set-hostname <your_device_name>
```

Then bring up Tailscale with SSH support:

```bash
sudo tailscale up --ssh
```

---

## 4.4 Update the real device token

1. In your browser, go to **[https://thingsboard.cloud/](https://thingsboard.cloud/)** → **Devices**.
2. Edit the device to copy its token.
3. On the device, open the environment file:

   ```bash
   nano ~/tango_remote_server/send_to_tb/.env
   ```
4. Replace the placeholder with your actual token:

   ```ini
   DEVICE_TOKEN=<YOUR_DEVICE_TOKEN>
   ```
5. Save and exit:

   ```bash
   Ctrl+X → Y → Enter
   ```

---

## 4.5 Start all services & reboot

```bash
cd ~/tango_remote_server
./scripts/setup_bash/setup_services.sh
sudo reboot
```

---

## Return to [Complete Guide](/docs/base_guide.md).

---
