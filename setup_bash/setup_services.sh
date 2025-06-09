#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "Error at line $LINENO: $BASH_COMMAND" >&2; exit 1' ERR

###############################################################################
# install_services.sh — Install and enable Sitrad and telemetry systemd units
# • Creates sitrad.service to launch Sitrad in headless Wine mode
# • Creates send_to_tb.service to push telemetry to ThingsBoard
# • Creates send_to_tb.timer to run the telemetry push every 30 seconds
# • Reloads systemd, enables & starts the units
# • Enables linger so user-level services start at boot without login
###############################################################################

BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UNIT_DIR="$HOME/.config/systemd/user"
mkdir -p "$UNIT_DIR"

# --- Setup sitrad.service ---
cat > "$UNIT_DIR/sitrad.service" <<EOF
[Unit]
Description=Run Sitrad 4.13 on boot and restart if it crashes
After=network.target

[Service]
Type=simple
Environment=DISPLAY=:1
Environment=WINEDEBUG=-all
Restart=always
RestartSec=3
WorkingDirectory=$BASEDIR/sitrad
ExecStart=$BASEDIR/sitrad/setup_sitrad.sh

[Install]
WantedBy=default.target
EOF

# --- Setup send_to_tb.service ---
cat > "$UNIT_DIR/send_to_tb.service" <<EOF
[Unit]
Description=Send telemetry to ThingsBoard

[Service]
Type=oneshot
WorkingDirectory=$BASEDIR/send_to_tb
ExecStart=$BASEDIR/send_to_tb/main.py
Environment=PYTHONUNBUFFERED=1
EOF

# --- Setup send_to_tb.timer ---
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

# --- Enable & start everything ---
echo "Reloading user systemd daemon and enabling units..."
systemctl --user daemon-reload

echo "Enabling + starting sitrad.service"
systemctl --user enable --now sitrad.service

echo "Enabling send_to_tb.timer"
systemctl --user enable --now send_to_tb.timer

echo "Kicking off an immediate telemetry push"
systemctl --user start send_to_tb.service

# --- Enable linger for user services at boot ---
echo "Enabling linger for user $(whoami) so services run at boot..."
sudo loginctl enable-linger "$(whoami)"

# --- Status summary ---
echo
echo "Services installed and running:"
echo "   • sitrad.service       (headless Wine + Xvfb, auto-restart)"
echo "   • send_to_tb.timer     (every 30 s)   + send_to_tb.service (immediate run)"
echo
echo "User-level systemd status:"
loginctl user-status "$(whoami)"

echo
echo "To monitor logs:"
echo "   journalctl --user -u sitrad.service -f"
echo "   journalctl --user -u send_to_tb.service -n 50"
