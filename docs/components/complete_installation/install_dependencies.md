
# Step 1 — Install Dependencies

---

## 1.1 Update the system

```bash
sudo apt update && sudo apt full-upgrade -y
```

---

## 1.2 Remove `brltty` (fixes FTDI detection issue)

`brltty` is a braille daemon that hijacks FTDI serial ports (like `/dev/ttyUSB0`), preventing Sitrad from seeing the converter.

```bash
sudo apt purge -y brltty
sudo apt autoremove --purge
```

You must now **unplug/re‑plug the USB‑RS485 adapter** or simply:

```bash
sudo reboot
```

After reboot:

```bash
ls -l /dev/ttyUSB0            # should now exist
ls -l /dev/serial/by-id/      # should list FT232 device
```

---

## 1.3 Required packages

### System packages

```bash
sudo apt install -y python3 python3-venv \
    xdotool xserver-xorg-video-dummy \
    xserver-xorg-legacy modemmanager \
    network-manager curl lightdm-settings sqlite3 \
    python3-pip python3-dev python3-spidev \
    python3-smbus python3-gpiod
```

> **Enable graphical autologin (LightDM)**
>
> 1. Launch the tool from CLI:
>
>    ```bash
>    sudo pkexec lightdm-settings
>    ```
> 2. Enter the password (`tango`), go to the **Users** tab.
> 3. Tick **Automatic login**, choose **tango** as the username, then click **Save**.

### Install Tailscale

```bash
curl -fsSL https://tailscale.com/install.sh | sh
```

### Python env

```bash
python3 -m venv venv --system-site-packages
source venv/bin/activate
pip install --upgrade pip
pip install requests python-dotenv
```

---

## 1.4 Enable ModemManager

```bash
sudo systemctl enable --now ModemManager
```

---

## 1.5 Configure the LTE modem (with APN)

To ensure your 4G/LTE modem connects automatically at boot, create a NetworkManager profile with the correct **APN (Access Point Name)** for your provider.

> **Why the APN matters**
> The APN tells the modem how to connect to your carrier’s mobile‑data network.

### 1.5.1 Find your provider’s APN

| Provider (Canada) | APN                         |
| ----------------- | --------------------------- |
| TELUS             | `sp.telus.com`              |
| Fido              | `fido-core-appl1.apn`       |
| Bell              | `pda.bell.ca`               |
| Rogers            | `internet.com`              |
| Freedom Mobile    | `internet.freedommobile.ca` |

If your carrier is not listed, check:

* Your provider’s documentation
* Online APN databases (e.g. *apn-canada.gishan.net*)
* The APN settings visible on a phone using the same SIM

### 1.5.2 Create the LTE connection profile

Replace **`sp.telus.com`** with your own APN if you are not on TELUS:

```bash
sudo nmcli connection add \
    type gsm \
    ifname "*" \
    con-name "TANGO-4G" \
    apn sp.telus.com \
    connection.autoconnect yes
```

This command instructs NetworkManager to:

* Manage any GSM modem detected (`ifname "*"`)
* Name the connection **TANGO-4G**
* Use the specified APN
* Connect automatically on boot

### 1.5.3 Verify the connection

```bash
mmcli -m 0          # Modem status
ip a show wwan0     # Interface details
curl ifconfig.me    # Public IP check
```

---

## 1.6 Bring the machine online (Tailscale)

Give your machine a unique hostname (to avoid name collisions on Tailscale):

```bash
sudo hostnamectl set-hostname <your_device_name>
sudo tailscale up --ssh
```

Open the authentication link printed by Tailscale, log in and connect.
Afterwards, you can SSH securely with Tailscale SSH.

---

Continue with **[Step 2 — Install Wine & Sitrad](install_sitrad.md)**.

---
