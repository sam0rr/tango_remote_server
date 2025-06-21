#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# uninstall_services.sh — Cleanup for all systemd services related to Sitrad
#  • Stops and disables display.service
#  • Stops and disables sitrad.service
#  • Stops and disables send_to_tb.timer + service
#  • Removes service files from ~/.config/systemd/user
#  • Deletes journald retention drop-in
#  • Removes Xwrapper.config
#  • Deletes Xorg dummy config
#  • Deletes residual Xorg log files
#  • Reloads systemd and disables linger
###############################################################################

UNIT_DIR="$HOME/.config/systemd/user"
RETENTION_DROPIN="/etc/systemd/journald.conf.d/00-retention.conf"
XWRAPPER_CONF="/etc/X11/Xwrapper.config"
DUMMY_CONF="/etc/X11/xorg.conf.d/10-dummy.conf"

echo "Uninstalling Services..."

# Kill Wine server (if running)
echo "Stopping Wine server…"
wineserver -k &> /dev/null || true

# 1) Stop & disable display.service
echo "Stopping and disabling display.service..."
systemctl --user stop display.service 2>/dev/null || true
systemctl --user disable display.service 2>/dev/null || true
rm -f "$UNIT_DIR/display.service"

# 2) Stop & disable sitrad.service
echo "Stopping and disabling sitrad.service..."
systemctl --user stop sitrad.service 2>/dev/null || true
systemctl --user disable sitrad.service 2>/dev/null || true
rm -f "$UNIT_DIR/sitrad.service"

# 3) Stop & disable send_to_tb.timer & service
echo "Stopping and disabling send_to_tb.timer and send_to_tb.service..."
systemctl --user stop send_to_tb.timer 2>/dev/null || true
systemctl --user disable send_to_tb.timer 2>/dev/null || true
systemctl --user stop send_to_tb.service 2>/dev/null || true
rm -f "$UNIT_DIR/send_to_tb.service" "$UNIT_DIR/send_to_tb.timer"

# 4) Remove journald retention drop-in
if [ -f "$RETENTION_DROPIN" ]; then
  echo "Removing journald retention drop-in: $RETENTION_DROPIN"
  sudo rm -f "$RETENTION_DROPIN"
  echo "Reloading systemd-journald to apply new config..."
  sudo systemctl restart systemd-journald
fi

# 5) Remove Xwrapper.config
if [ -f "$XWRAPPER_CONF" ]; then
  echo "Removing Xwrapper.config: $XWRAPPER_CONF"
  sudo rm -f "$XWRAPPER_CONF"
fi

# 6) Delete Xorg dummy configuration
if [ -f "$DUMMY_CONF" ]; then
  echo "Deleting Xorg dummy configuration: $DUMMY_CONF"
  sudo rm -f "$DUMMY_CONF"
fi

# 7) Delete residual Xorg log files
echo "Deleting residual Xorg log files..."
rm -f ~/.local/share/xorg/Xorg.1.log ~/.xsession-errors* ~/.Xauthority || true

# 8) Reload systemd user daemon
echo "Reloading systemd user daemon..."
systemctl --user daemon-reload

# 9) Disable linger for user
echo "Disabling linger for user $(whoami)..."
sudo loginctl disable-linger "$(whoami)" || true

# 10) Final summary
cat <<EOF

Uninstallation complete.
Remaining user unit files in $UNIT_DIR:
  $(ls -1 "$UNIT_DIR" || echo "(none)")

To verify:
  systemctl --user list-units --type=service
  systemctl --user list-timers
EOF
