#!/usr/bin/env bash
set -euo pipefail

echo "Checking environment…"

# Verify that we are in an X11 session (DISPLAY=:1 via Xvfb)
if [[ -z "${DISPLAY:-}" ]]; then
    echo "DISPLAY is not set. Run in a graphical X11 session (or Xvfb)."
    exit 1
fi

if ! [[ $DISPLAY =~ :[0-9]+ ]]; then
    echo "DISPLAY format ($DISPLAY) doesn't look like X11."
    exit 1
fi

echo "X11 session detected (DISPLAY=$DISPLAY)"

# Locate the Sitrad window
echo "Searching for 'Sitrad Local' window…"
WID=$(xdotool search --name "Sitrad Local" | head -n 1 || true)

if [[ -z "${WID:-}" ]]; then
    echo "Window not found: make sure Sitrad is open."
    exit 1
fi

echo "Found window ID: $WID"

# Send Ctrl+L directly to that window
echo "→ Sending: xdotool key --window $WID ctrl+l"
if xdotool key --window "$WID" ctrl+l; then
    echo "Success: Ctrl+L sent."
    exit 0
fi

echo "Failed to send Ctrl+L. Ensure xdotool can control windows."
exit 1
