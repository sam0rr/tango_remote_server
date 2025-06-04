#!/usr/bin/env bash
set -euo pipefail

BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UNIT_DIR="$HOME/.config/systemd/user"
SCRIPT_PATH="$BASEDIR/send_to_tb/main.py"

echo "🔧reating systemd timer for:"
echo "    $SCRIPT_PATH"

mkdir -p "$UNIT_DIR"

# SERVICE
cat > "$UNIT_DIR/send_to_tb.service" <<EOF
[Unit]
Description=Send telemetry to ThingsBoard

[Service]
Type=oneshot
WorkingDirectory=$BASEDIR/send_to_tb
ExecStart=$SCRIPT_PATH
Environment="PYTHONUNBUFFERED=1"
EOF

# TIMER
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

# Apply
echo "Reloading systemd and enabling timer..."
systemctl --user daemon-reload
systemctl --user enable --now send_to_tb.timer

echo "Timer installed and running. View with:"
echo "   systemctl --user list-timers"
echo "To see logs: journalctl --user -u send_to_tb.service -n 50"
