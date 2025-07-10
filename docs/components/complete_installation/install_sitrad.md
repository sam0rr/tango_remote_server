
# Step 2 — Install Wine 32-bit & Sitrad 4.13

---

## 2.1 Install Wine via Pi-Apps

```bash
# Clone and install Pi-Apps
cd
git clone https://github.com/Botspot/pi-apps ~/pi-apps
~/pi-apps/install

# Launch the GUI, then choose:
pi-apps
```

Once open:
1. Select Tools
2. Select Emulation
3. Select Hangover
4. Select install
5. Wait for installation

**Recommended: Install Known Working Box64 for Sitrad**

Some recent Box64 builds cause issues with COM ports or Wine execution. We strongly recommend installing a tested working version that supports Sitrad 4.13 reliably:

```bash
sudo dpkg -i ~/tango_remote_server/assets/box64_working_for_sitrad_20250701.deb
sudo apt-mark hold box64-generic-arm
apt policy box64-generic-arm
```

You should see:
```
Installed: 0.3.7+20250701T062936.54ea485-1
```

This prevents automatic upgrades that might break compatibility. To allow updates again in the future:

```bash
sudo apt-mark unhold box64-generic-arm
```

---

## 2.2 Install Sitrad 4.13

```bash
# Stop any running Wine server if any
wineserver -k

# Run the Sitrad installer and follow steps
wine ~/tango_remote_server/assets/SetupLocal.exe
```

---

Continue with **[Step 3 — Install Services & Deploy](install_services.md)**.

---
