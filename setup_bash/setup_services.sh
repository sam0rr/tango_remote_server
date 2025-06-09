#!/usr/bin/env bash
set -euo pipefail

# Base directory of the project
BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# User systemd unit directory
UNIT_DIR="$HOME/.config/systemd/user"
mkdir -p "$UNIT_DIR"

# --- 1) Headless X session service (Xvfb + Openbox) ---
cat > "$UNIT_DIR/sitrad-display.service" <<EOF
[Unit]
Description=Headless X session for Sitrad
After=network.target

[Service]
Type=simple
Environment=DISPLAY=:1
ExecStartPre=/usr/bin/sh -c 'Xvfb :1 -screen 0 1024x768x16 -ac >/dev/null 2>&1 & sleep 1'
ExecStart=/usr/bin/openbox
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
EOF

# --- 2) Sitrad application service (Wine + Ctrl+L) ---
SITRAD_SCRIPT="$BASEDIR/sitrad/setup_sitrad.sh"
cat > "$UNIT_DIR/sitrad-app.service" <<EOF
[Unit]
Description=Launch Sitrad 4.13 and auto Ctrl+L
After=sitrad-display.service
Requires=sitrad-display.service

[Service]
Type=simple
Environment=DISPLAY=:1
Environment=WINEDEBUG=-all
WorkingDirectory=$BASEDIR/sitrad

ExecStartPre=/usr/bin/udevadm settle --timeout=30
ExecStart=$SITRAD_SCRIPT

Restart=always
RestartSec=3

[Install]
WantedBy=default.target
EOF

# --- 3) Telemetry service + timer ---
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
OnBootSec=10s
OnUnitActiveSec=30s
AccuracySec=1s
Persistent=true

[Install]
WantedBy=timers.target
EOF

# --- Enable and start services/timers ---
echo "Reloading user systemd units..."
systemctl --user daemon-reload
echo "Enabling and starting services..."
systemctl --user enable --now sitrad-display.service
systemctl --user enable --now sitrad-app.service
systemctl --user enable --now send_to_tb.timer

echo -e "
Services installed and running:"
echo "  - sitrad-display.service  (Xvfb + Openbox)"
echo "  - sitrad-app.service      (Wine + auto Ctrl+L)"
echo "  - send_to_tb.timer        (runs every 30s)"
echo -e "
To monitor:"
echo "  journalctl --user -u sitrad-display.service -f"
echo "  journalctl --user -u sitrad-app.service     -f"
echo "  journalctl --user -u send_to_tb.service -n 50"
