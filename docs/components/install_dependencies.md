
# Step 1 — Install Dependencies
---

## 1.1 Update the system
```bash
sudo apt update && sudo apt full-upgrade -y
```

## 1.2 Remove `brltty` (fixes FTDI detection issue)

`brltty` is a braille daemon that hijacks FTDI serial ports (like `/dev/ttyUSB0`), preventing Sitrad from seeing the converter.

```bash
sudo apt purge -y brltty
```

You must now **unplug/re-plug the USB-RS485 adapter** or simply:

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
    modemmanager network-manager curl \
    lightdm-settings
```

> **Enable graphical autologin (XFCE / LightDM)**  
> 1. Launch the tool from CLI:  
>    ```bash
>    pkexec lightdm-settings
>    ```  
>    or open **Applications ▸ Settings ▸ Login Window**.  
> 2. Enter the password (`tango`), go to the **Users** tab.  
> 3. Tick **Automatic login**, choose **tango** as the username, then click **Save**.

> **Armbian Bookworm only**  
> `xserver-xorg-legacy` is **required** so headless Xorg can get VT permissions.  
> The install script will add it automatically if it’s missing, but you can do it now:
> ```bash
> sudo apt install -y xserver-xorg-legacy
> sudo tee /etc/X11/Xwrapper.config >/dev/null <<'EOF'
> allowed_users=anybody
> needs_root_rights=yes
> EOF
> ```

### Install Tailscale
```bash
curl -fsSL https://tailscale.com/install.sh | sh
```

### Python env
```bash
python3 -m venv venvx
source venvx/bin/activate
pip install --upgrade pip
pip install requests python-dotenv
```

## 1.4 Enable ModemManager
```bash
sudo systemctl enable --now ModemManager
```

## 1.5 Verify LTE connectivity
```bash
mmcli -m 0          # Modem status
ip a show wwan0     # Interface details
curl ifconfig.me    # Public IP check
```

## 1.6 Bring the machine online (Tailscale)
```bash
sudo tailscale up --ssh
```

Open the authentication link printed by Tailscale, log in, and add the desired machine tag in the Tailscale admin console.  
Afterwards, you can SSH securely with Tailscale SSH.

---

Continue with **[Step 2 — Install Wine & Sitrad](install_sitrad.md)**.

---
