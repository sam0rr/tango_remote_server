#!/usr/bin/env bash
set -euo pipefail

# Directory for user-level systemd units
target_dir="$HOME/.config/systemd/user"

echo "Uninstalling sitrad-display, sitrad-app, and send_to_tb services..."

# 1) Stop Wine server (if running)
echo "Stopping Wine server..."
wineserver -k &> /dev/null || true

# 2) Disable and remove display unit
echo "Stopping and disabling sitrad-display.service..."
systemctl --user stop sitrad-display.service || true
systemctl --user disable sitrad-display.service || true
rm -f "$target_dir/sitrad-display.service"

# 3) Disable and remove application unit
echo "Stopping and disabling sitrad-app.service..."
systemctl --user stop sitrad-app.service || true
systemctl --user disable sitrad-app.service || true
rm -f "$target_dir/sitrad-app.service"

# 4) Disable and remove telemetry timer and service
echo "Stopping and disabling send_to_tb.timer and send_to_tb.service..."
systemctl --user stop send_to_tb.timer || true
systemctl --user disable send_to_tb.timer || true
systemctl --user stop send_to_tb.service || true
systemctl --user disable send_to_tb.service || true
rm -f "$target_dir/send_to_tb.service" "$target_dir/send_to_tb.timer"

# 5) Reload user systemd daemon
echo "Reloading user systemd daemon..."
systemctl --user daemon-reload

echo -e "
All specified services have been uninstalled."
echo "Verify with:"
echo "  systemctl --user list-units --type=service"
echo "  systemctl --user list-timers"
