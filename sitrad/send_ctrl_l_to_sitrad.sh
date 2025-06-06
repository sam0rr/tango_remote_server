#!/usr/bin/env bash
set -euo pipefail

echo "Checking environment…"

# Ensure XAUTHORITY points to a user‐writable file
: "${XAUTHORITY:="$HOME/.Xauthority"}"
if [[ ! -f "$XAUTHORITY" ]]; then
    touch "$XAUTHORITY"
    chmod 600 "$XAUTHORITY"
fi

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
WIDS=$(xdotool search --name "Sitrad Local" 2>/dev/null || true)
if [[ -z "$WIDS" ]]; then
    echo "Window not found: make sure Sitrad is open."
    exit 1
fi

# If multiple windows match, pick the first exact "Sitrad Local"
TARGET=""
for W in $WIDS; do
    TITLE=$(xdotool getwindowname "$W")
    if [[ "$TITLE" == *"Sitrad Local"* ]]; then
        TARGET=$W
        break
    fi
done

if [[ -z "$TARGET" ]]; then
    echo "No exact match for 'Sitrad Local' found among candidates."
    exit 1
fi

echo "Found window ID: $TARGET"

# Give the Sitrad window the input focus (via windowmap + windowactivate)
echo "→ Mapping and focusing window $TARGET"
xdotool windowmap "$TARGET"
sleep 0.1
xdotool windowactivate "$TARGET"
sleep 0.3

# Then send Ctrl+L directly to that window
echo "→ Sending: xdotool key --window $TARGET ctrl+l"
if xdotool key --window "$TARGET" ctrl+l; then
    echo "Success: Ctrl+L sent."
    exit 0
fi

echo "Failed to send Ctrl+L. Ensure xdotool can control windows."
exit 1
