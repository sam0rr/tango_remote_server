
# Step 2 — Install Wine (Hangover) & Sitrad 4.13

---

## 2.1 Install Hangover via Direct Script

```bash
curl -sSL https://raw.githubusercontent.com/sam0rr/hangover-wine-easy-download/main/install-hangover.sh | bash
```

**To uninstall Hangover later if needed:**

```bash
curl -sSL https://raw.githubusercontent.com/sam0rr/hangover-wine-easy-download/main/uninstall-hangover.sh | bash
```

**Why Hangover?** Hangover runs Win64 and Win32 applications on arm64 Linux. Only the application is emulated instead of a whole Wine installation, providing better resource efficiency with less CPU and memory usage than full Wine-through-Box64 setups.

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
