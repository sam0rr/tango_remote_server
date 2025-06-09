#!/usr/bin/env bash
set -euo pipefail

BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UNIT_DIR="$HOME/.config/systemd/user"
mkdir -p "$UNIT_DIR"

# --- Setup Sitrad Service ---
SITRAD_SCRIPT="$BASEDIR/sitrad/setup_sitrad.sh"
cat > "$UNIT_DIR/sitrad.service" <<EOF
[Unit]
Description=Run Sitrad 4.13 on boot and restart if it crashes
After=network.target

[Service]
Type=idle
Environment=DISPLAY=:1
Environment=WINEDEBUG=-all
Restart=always
RestartSec=3

WorkingDirectory=$BASEDIR/sitrad
ExecStart=$SITRAD_SCRIPT

[Install]
WantedBy=default.target
EOF

# --- Setup send_to_tb Service + Timer ---
SEND_SCRIPT="$BASEDIR/send_to_tb/main.py"
cat > "$UNIT_DIR/send_to_tb.service" <<EOF
[Unit]
Description=Send telemetry to ThingsBoard

[Service]
Type=oneshot
WorkingDirectory=$BASEDIR/send_to_tb
ExecStart=$SEND_SCRIPT
Environment=PYTHONUNBUFFERED=1
EOF

cat > "$UNIT_DIR/send_to_tb.timer" <<EOF
[Unit]
Description=Run send_to_tb.service every 30 seconds

[Timer]
OnBootSec=10
OnUnitActiveSec=30s
AccuracySec=1s
Persistent=true

[Install]
WantedBy=timers.target
EOF

# --- Enable Services ---
echo "Reloading systemd and enabling services..."
systemctl --user daemon-reload
systemctl --user enable --now sitrad.service
systemctl --user enable --now send_to_tb.timer

echo -e "\nServices installed and running:"
echo "   - sitrad.service      (restart on crash, headless Xvfb via setup_sitrad.sh)"
echo "   - send_to_tb.timer    (runs every 30s)"
echo -e "\nTo monitor:"
echo "   journalctl --user -u sitrad.service -f"
echo "   journalctl --user -u send_to_tb.service -n 50"
