#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# install_services.sh — Install and enable:
#  • journald retention policy (auto-prune old logs)
#  • Xorg dummy driver configuration
#  • display.service       (Xorg)
#  • sitrad.service        (Wine Sitrad under virtual display)
#  • send_to_tb.service    (telemetry push to ThingsBoard)
#  • send_to_tb.timer      (runs every 30 seconds)
#  • user-level lingering for autostart at boot
###############################################################################

BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
UNIT_DIR="$HOME/.config/systemd/user"

# 0) Create journald retention drop-in so logs auto-prune
echo "Configuring journal retention..."
sudo mkdir -p /etc/systemd/journald.conf.d
sudo tee /etc/systemd/journald.conf.d/00-retention.conf >/dev/null <<'EOF'
[Journal]
Storage=persistent
SystemMaxUse=200M
SystemKeepFree=50M
SystemMaxFileSize=50M
SystemMaxFiles=5
MaxFileSec=1day
MaxRetentionSec=7day
EOF
sudo systemctl restart systemd-journald

# 0-bis) Ensure Xorg has root rights on headless Armbian
if ! dpkg -s xserver-xorg-legacy >/dev/null 2>&1; then
  echo "Installing xserver-xorg-legacy (needed on Armbian)…"
  sudo apt update
  sudo apt install -y xserver-xorg-legacy
  sudo tee /etc/X11/Xwrapper.config >/dev/null <<'EOF'
allowed_users=anybody
needs_root_rights=yes
EOF
fi

# 0-ter) Ensure the Xorg dummy video driver is present
if ! dpkg -s xserver-xorg-video-dummy >/dev/null 2>&1; then
  echo "Installing xserver-xorg-video-dummy (virtual display)…"
  sudo apt update
  sudo apt install -y xserver-xorg-video-dummy
fi

# 1) Install Xorg dummy configuration
echo "Installing Xorg dummy driver configuration..."
sudo mkdir -p /etc/X11/xorg.conf.d
sudo tee /etc/X11/xorg.conf.d/10-dummy.conf >/dev/null <<'EOF'
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

# 3) Create display.service: Xorg dummy
cat > "$UNIT_DIR/display.service" <<EOF
[Unit]
Description=Headless Xorg (dummy) for Sitrad
After=network.target

[Service]
Type=simple
Environment=DISPLAY=:1
ExecStart=/bin/sh -c 'rm -f /tmp/.X1-lock && cd /etc/X11 && \
    /usr/bin/Xorg :1 -configdir xorg.conf.d -nolisten tcp -quiet -noreset'
ExecStop=/usr/bin/killall -q Xorg
KillMode=control-group
ProtectHome=yes
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
EOF

# 4) Create sitrad.service (depends on display)
SITRAD_SCRIPT="$BASEDIR/scripts/sitrad/setup_sitrad.sh"
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
WorkingDirectory=$BASEDIR/scripts/sitrad
ExecStart=$SITRAD_SCRIPT
Restart=always
RestartSec=3

[Install]
WantedBy=default.target
EOF

# 5) Create send_to_tb.service (push telemetry)
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

# 7) Reload systemd and enable everything
echo "Reloading systemd user units..."
systemctl --user daemon-reload

echo "Enabling and starting services..."
systemctl --user enable --now display.service
systemctl --user enable --now sitrad.service
systemctl --user enable --now send_to_tb.timer

# 8) Enable linger so user services auto-start at boot
echo "Enabling linger for user $(whoami)..."
sudo loginctl enable-linger "$(whoami)"

# 9) Final summary
cat <<EOF

Services installed and running:
   - journald retention policy (200M / 7d)
   - display.service      (Xorg dummy only)
   - sitrad.service       (Wine Sitrad using DISPLAY=:1)
   - send_to_tb.timer     (pushes data every 30 seconds)

To monitor logs:
   journalctl --user -u display.service -f        # Follow Xorg Display logs
   journalctl --user -u sitrad.service -f         # Follow Sitrad logs
   journalctl --user -u send_to_tb.service -n 50  # Last 50 lines of telemetry-sender logs
   journalctl --disk-usage
EOF
