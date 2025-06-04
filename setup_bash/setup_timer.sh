#!/usr/bin/env bash
set -euo pipefail

# Get current directory (e.g. /home/ecarbonn/scripts/send_to_tb)
WORKDIR="$(pwd)"
UNIT_DIR="$HOME/.config/systemd/user"

echo "🔧 Creating systemd timer for:"
echo "    $WORKDIR/main.py"

mkdir -p "$UNIT_DIR"

# SERVICE
cat > "$UNIT_DIR/send_to_tb.service" <<EOF
[Unit]
Description=Send telemetry to ThingsBoard

[Service]
Type=oneshot
WorkingDirectory=$WORKDIR
ExecStart=$WORKDIR/main.py
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
