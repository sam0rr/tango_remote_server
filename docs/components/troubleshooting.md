
# TROUBLESHOOTING

---

**Q: How do I verify that rows were removed?**

```bash
sudo apt install -y sqlite3    # If not already installed
sqlite3 ~/.wine/drive_c/ProgramData/Full\ Gauge/Sitrad/data.db "SELECT COUNT(*) FROM tc900log;"
```

---

**Q: How do I check if the script is running?**

```bash
systemctl --user list-timers
```

---

**Q: How do I view the send logs?**

```bash
journalctl --user -u display.service -f        # Follow Xorg Display logs
journalctl --user -u sitrad.service -f         # Follow Sitrad logs
journalctl --user -u send_to_tb.service -n 50  # Show last 50 lines of telemetry sender
journalctl --disk-usage                        # Check disk usage of logs
```

---

**Q: Where should I run `chmod +x`?**

```bash
cd ~/tango_remote_server/

chmod +x send_to_tb/main.py
chmod +x scripts/sitrad/setup_sitrad.sh
chmod +x scripts/sitrad/send_ctrl_l_to_sitrad.sh
chmod +x scripts/setup_bash/setup_services.sh
chmod +x scripts/setup_bash/kill_services.sh
```

---

**Q: How can I test without actually sending data?**

Temporarily add this to your `.env` file:

```ini
MAX_MSGS_PER_SEC=0
```

---

**Q: How can I access my devices remotely?**

Use the **Tailscale SSH console** in the admin panel to manage your machine from anywhere:  
-> https://login.tailscale.com/admin/machines

Steps:

1. Click the **three dots** next to the correct device.
2. Select **SSH**.
3. Choose **Other → tango → SSH**.
4. Log in.
5. Wait for the terminal to connect.

---

Go back to **[Installation Guide](/docs/install_guide.md)**.

---
