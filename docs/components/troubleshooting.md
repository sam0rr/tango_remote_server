
# TROUBLESHOOTING

**Q: How do I verify that rows were removed?**

```bash
sudo apt install -y sqlite3    # If not installed (READ database)
sqlite3 ~/.wine/drive_c/ProgramData/Full\ Gauge/Sitrad/data.db "SELECT COUNT(*) FROM tc900log;"
```

**Q: How do I check if the script is running?**

```bash
systemctl --user list-timers
```

**Q: How do I view the send logs?**

```bash
journalctl --user -u display.service -f        # Follow Xorg Display logs
journalctl --user -u sitrad.service -f         # Follow Sitrad logs
journalctl --user -u send_to_tb.service -n 50  # Last 50 lines of telemetry‐sender logs
journalctl --disk-usage
```

**Q: Where should I run `chmod +x`?**

```bash
cd ~/tango_remote_server/scripts/
chmod +x send_to_tb/main.py
chmod +x sitrad/setup_sitrad.sh
chmod +x sitrad/send_ctrl_l_to_sitrad.sh
chmod +x setup_bash/setup_services.sh
chmod +x setup_bash/kill_services.sh
```

**Q: How can I test without actually sending data?**

Temporarily set:

```ini
MAX_MSGS_PER_SEC=0
```

**Q: How can I access devices rem?**

Use the Tailscale SSH console in the admin panel to manage your Pi from anywhere. 

 

Your Raspberry Pi is now fully configured with 4G LTE connectivity, secure Tailscale networking, and Sitrad 4.13 running under Wine. 

---

Go back to root **[install_guide](/docs/install_guide.md)**.

---
