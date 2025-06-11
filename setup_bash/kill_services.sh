#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# uninstall_services.sh — Cleanup for all systemd services related to Sitrad
#  • Stops and disables display.service
#  • Stops and disables sitrad.service
#  • Stops and disables send_to_tb.timer + service
#  • Removes service files from ~/.config/systemd/user
#  • Deletes Xorg dummy config
#  • Reloads systemd and disables linger
###############################################################################

UNIT_DIR="$HOME/.config/systemd/user"
DUMMY_CONF="/etc/X11/xorg.conf.d/10-dummy.conf"

echo "Uninstalling Services..."

# Kill wine server (if running)
echo "Stopping Wine server…"
wineserver -k &> /dev/null || true

# 1) Stop & disable display.service
echo "Stopping and disabling display.service..."
systemctl --user stop display.service 2>/dev/null || true
systemctl --user disable display.service 2>/dev/null || true
rm -f "$UNIT_DIR/display.service"

echo "Deleting Xorg dummy configuration: $DUMMY_CONF"
sudo rm -f "$DUMMY_CONF"

# 2) Stop & disable sitrad.service
echo "Stopping and disabling sitrad.service..."
systemctl --user stop sitrad.service 2>/dev/null || true
systemctl --user disable sitrad.service 2>/dev/null || true
rm -f "$UNIT_DIR/sitrad.service"

# 3) Stop & disable send_to_tb.timer & service
echo "Stopping and disabling send_to_tb.timer and service..."
systemctl --user stop send_to_tb.timer 2>/dev/null || true
systemctl --user disable send_to_tb.timer 2>/dev/null || true
systemctl --user stop send_to_tb.service 2>/dev/null || true
rm -f "$UNIT_DIR/send_to_tb.service" "$UNIT_DIR/send_to_tb.timer"

# 4) Reload systemd user daemon
echo "Reloading systemd user daemon..."
systemctl --user daemon-reload

# 5) Disable linger for user
echo "Disabling linger for user $(whoami)..."
sudo loginctl disable-linger "$(whoami)" || true

# 6) Final summary
cat <<EOF

Uninstallation complete.
Remaining user unit files in $UNIT_DIR:
  $(ls -1 "$UNIT_DIR" || echo "(none)")
To verify:
  systemctl --user list-units --type=service
  systemctl --user list-timers
EOF
