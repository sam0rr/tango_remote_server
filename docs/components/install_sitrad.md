
# Step 2 — Install Wine 32-bit & Sitrad 4.13

## 2.1 Install the armbian-gaming repo

Clone the armbian-gaming repo and run the installer:

```bash
git clone https://github.com/NicoD-SBC/armbian-gaming.git
cd armbian-gaming
/bin/bash ./armbian-gaming.sh
```

When prompted:

* **Option 2 – Install/Update Box86**

  * Choose **5 – Raspberry Pi**
  * **OR**
  * Choose **6 – Other ARM64**
* **Option 5 – Install winetricks**
* **Option 4 – Install Wine x86 files**

---

## 2.2 Install Sitrad 4.13

Run the Sitrad installer:

```bash
wine ~/tango_remote_server/assets/SetupLocal.exe
```

Follow the on-screen prompts to complete the installation.

---

## Continue with **[Step 3 — Install Services & Deploy](install_services.md)**.

---