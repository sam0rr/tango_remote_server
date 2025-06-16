
# Step 2 — Install Wine 32-bit & Sitrad 4.13

---

## 2.1 Install Wine via Pi-Apps

```bash
# Clone and install Pi-Apps
git clone https://github.com/Botspot/pi-apps ~/pi-apps
~/pi-apps/install

# Launch the GUI, then choose:
pi-apps
```

Once open:

1. Select Tools 
2. Select Emulation
3. Select Wine
4. Select install 
5. Wait for installation 

## 2.2 Install Sitrad 4.13

```bash
# Stop any running Wine server if any
wineserver -k

# Run the Sitrad installer and follow steps
wine ~/tango_remote_server/assets/SitradLocal.exe
```

---

Continue with **[Step 3 — Install Services & Deploy](install_services.md)**.

---