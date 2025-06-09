#!/usr/bin/env bash
set -euo pipefail

# ── 0) Ensure we talk to the right X server ───────────────────────────────────
export DISPLAY=:1
echo "Using DISPLAY=$DISPLAY"

# ── 1) Find the Sitrad window ─────────────────────────────────────────────────
echo "Searching for 'Sitrad Local'…"
WID=$(xdotool search --onlyvisible --name "Sitrad Local" 2>/dev/null | head -n1)

if [[ -z "$WID" ]]; then
  echo "Window not found (try: xdotool search --name Sitrad)"
  exit 1
fi
echo "Found window ID: $WID"

# ── 2) Focus it ────────────────────────────────────────────────────────────────
xdotool windowmap    "$WID"
sleep 0.1
xdotool windowactivate "$WID"
sleep 0.2

# ── 3) Send Ctrl+L ─────────────────────────────────────────────────────────────
echo "→ Sending Ctrl+L to window $WID"
if xdotool key --window "$WID" ctrl+l; then
  echo "Ctrl+L sent."
  exit 0
else
  echo "Failed to send Ctrl+L."
  exit 1
fi
