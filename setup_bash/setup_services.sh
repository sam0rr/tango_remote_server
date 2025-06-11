#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# install_services.sh — Install and enable:
#  • Xorg dummy configuration
#  • display.service       (headless Xorg+dummy + Openbox)
#  • sitrad.service       (wine Sitrad under headless display)
#  • send_to_tb.service   (telemetry push)
#  • send_to_tb.timer     (every 30 seconds)
#  • linger for user-level services
###############################################################################

BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UNIT_DIR="$HOME/.config/systemd/user"

# 1) Install Xorg dummy driver configuration
echo "➡ Installing Xorg dummy driver configuration..."
sudo mkdir -p /etc/X11/xorg.conf.d
sudo tee /etc/X11/xorg.conf.d/10-dummy.conf > /dev/null <<'EOF'
Section "Device"
    Identifier  "DummyDevice"
    Driver      "dummy"
EndSection

Section "Monitor"
    Identifier  "DummyMonitor"
    HorizSync   28.0-80.0
    VertRefresh 48.0-75.0
EndSection

Section "Screen"
    Identifier   "DummyScreen"
    Device       "DummyDevice"
    Monitor      "DummyMonitor"
    DefaultDepth 24
    SubSection "Display"
        Depth     24
        Modes     "1024x768"
    EndSubSection
EndSection
EOF

echo "/etc/X11/xorg.conf.d/10-dummy.conf created"

# 2) Prepare user systemd directory
mkdir -p "$UNIT_DIR"

# 3) Create display.service (headless Xorg+dummy + Openbox)
cat > "$UNIT_DIR/display.service" <<EOF
[Unit]
Description=Headless Xorg (dummy) + Openbox display for Sitrad
After=network.target

[Service]
Type=simple
Environment=DISPLAY=:1
ExecStart=/usr/bin/Xorg :1 \
    -config /etc/X11/xorg.conf.d/10-dummy.conf \
    -nolisten tcp vt7
ExecStartPost=/usr/bin/openbox --display :1
Restart=always
RestartSec=2

[Install]
WantedBy=default.target
EOF

# 4) Create sitrad.service (runs after display.service)
SITRAD_SCRIPT="$BASEDIR/sitrad/setup_sitrad.sh"
cat > "$UNIT_DIR/sitrad.service" <<EOF
[Unit]
Description=Run Sitrad 4.13 under Wine (headless)
After=network.target display.service
Requires=display.service

[Service]
Type=simple
Environment=DISPLAY=:1
Environment=XAUTHORITY=%h/.Xauthority
Environment=WINEDEBUG=-all
WorkingDirectory=$BASEDIR/sitrad
ExecStart=$SITRAD_SCRIPT
Restart=always
RestartSec=3

[Install]
WantedBy=default.target
EOF

# 5) Create send_to_tb.service (telemetry push)
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

# 6) Create send_to_tb.timer (every 30 seconds)
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

# 7) Reload and enable user services
echo "➡ Reloading systemd user units..."
systemctl --user daemon-reload

# Enable and start display & sitrad services
systemctl --user enable display.service --now
systemctl --user enable sitrad.service --now

# Enable and start telemetry timer
systemctl --user enable send_to_tb.timer --now

# 8) Enable user linger for services at boot
echo "➡ Enabling linger for user $(whoami)..."
sudo loginctl enable-linger "$(whoami)"

# 9) Summary echo
cat <<EOF

Services installed and running:
   - display.service      (headless Xorg+dummy + Openbox)
   - sitrad.service       (Wine Sitrad under headless display)
   - send_to_tb.timer     (runs every 30 seconds)

To monitor logs:
   journalctl --user -u display.service -f
   journalctl --user -u sitrad.service -f
   journalctl --user -u send_to_tb.service -n 50
EOF
