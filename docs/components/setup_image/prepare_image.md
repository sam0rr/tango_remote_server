
# Step 1 - Prepare Cloneable Image

---

The `prepare_image.sh` script cleans and finalizes the system **before** creating a clonable SD-card image. Running this script ensures that each cloned device:

* **Stops** all custom user services (Sitrad, telemetry)
* **Resets** the `DEVICE_TOKEN` placeholder in the `.env`
* **Disconnects** and **clears** Tailscale state
* **Performs** a 5‑second shutdown countdown

---

## 1.1 Make the script executable (if not already)

   ```bash
   chmod +x scripts/setup_bash/prepare_image.sh
   ```

---

## 1.2 Run the script as your normal user

   ```bash
   ./scripts/setup_bash/prepare_image.sh
   ```

    The script will:

   1. Stop all user custom services
   2. Replace `DEVICE_TOKEN=...` in `send_to_tb/.env` with `<YOUR_DEVICE_TOKEN>`
   3. Run `tailscale down`, `tailscale logout`, remove `/var/lib/tailscale`,
      and call `tailscaled --cleanup`
   4. Count down 5 seconds, then power off the device

---

Continue with **[Create image of SD-card](create_image.md)**.

---
