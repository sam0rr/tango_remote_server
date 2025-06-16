
# Step 1 — Install Dependencies

## 1.1 Update the system

```bash
sudo apt update && sudo apt full-upgrade -y
```

## 1.2 Required packages

### System packages

```bash
sudo apt install -y python3 python3-venv \
    xdotool xserver-xorg-video-dummy \
    modemmanager network-manager curl
```

### Install Tailscale

```bash
curl -fsSL https://tailscale.com/install.sh | sh
```

### Python env

```bash
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install requests python-dotenv
```

## 1.3 Enable ModemManager

```bash
sudo systemctl enable --now ModemManager
```

## 1.4 Verify LTE connectivity

```bash
mmcli -m 0          # Modem status
ip a show wwan0     # Interface details
curl ifconfig.me    # Public IP check
```


## 1.5  Bring the Pi online (Tailscale)

```bash
sudo tailscale up --ssh
```

Open the authentication link printed by Tailscale, log in, and add the desired raspberrypi tag in the Tailscale admin console. 
Afterwards, you can SSH securely with Tailscale SSH. 

---

Continue with **[Step 2 — Install Wine & Sitrad](install_sitrad.md)**.

---
