#!/usr/bin/env bash
set -euo pipefail

UNIT_DIR="$HOME/.config/systemd/user"

echo "Uninstalling send_to_tb timer and service..."

# Stop and disable
systemctl --user stop send_to_tb.timer || true
systemctl --user disable send_to_tb.timer || true
systemctl --user stop send_to_tb.service || true

# Remove files
rm -f "$UNIT_DIR/send_to_tb.service"
rm -f "$UNIT_DIR/send_to_tb.timer"

# Reload systemd
systemctl --user daemon-reload

echo "Uninstalled."
echo "You can verify with: systemctl --user list-timers"
