
# Step 2 — Install Wine (Hangover) & Sitrad 4.13

---

## 2.1 Install Hangover via Pi-Apps

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

**Why Hangover?**
Hangover runs Win64 and Win32 applications on arm64 Linux. Only the application is emulated instead of a whole Wine installation, providing better resource efficiency with less CPU and memory usage than full Wine-through-Box64 setups.

---

## 2.2 Install Sitrad 4.13

```bash
# Stop any running Wine server if any
wineserver -k

# Run the Sitrad installer and follow steps
wine ~/tango_remote_server/assets/SetupLocal.exe
```

---

Continue with **[Step 3 — Install Services & Deploy](install_services.md)**.

---
