#!/usr/bin/env bash

###############################################################################
# uninstall_services.sh — Cleanup for all systemd services related to Sitrad
# • Stops and disables sitrad.service
# • Stops and disables send_to_tb.timer + service
# • Removes service files from ~/.config/systemd/user
# • Reloads systemd and exits cleanly
###############################################################################

set -euo pipefail

UNIT_DIR="$HOME/.config/systemd/user"

echo "Uninstalling sitrad + send_to_tb services..."

# Kill wine server (if running)
echo "Stopping Wine server..."
wineserver -k &> /dev/null || true

# Stop & disable Sitrad
echo "Disabling sitrad.service..."
systemctl --user stop sitrad.service || true
systemctl --user disable sitrad.service || true
rm -f "$UNIT_DIR/sitrad.service"

# Stop & disable send_to_tb
echo "Disabling send_to_tb.timer and service..."
systemctl --user stop send_to_tb.timer || true
systemctl --user disable send_to_tb.timer || true
systemctl --user stop send_to_tb.service || true
rm -f "$UNIT_DIR/send_to_tb.service" "$UNIT_DIR/send_to_tb.timer"

# Reload systemd
echo "Reloading systemd daemon..."
systemctl --user daemon-reload

echo -e "\nUninstalled."
echo "You can check with:"
echo "   systemctl --user list-timers"
echo "   systemctl --user list-units --type=service"