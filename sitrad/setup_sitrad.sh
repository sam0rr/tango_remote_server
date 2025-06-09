#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "Error line $LINENO: $BASH_COMMAND" >&2' ERR

###############################################################################
#  setup_sitrad.sh — Smart launcher for Sitrad 4.13 on Raspberry Pi (headless)
#  • Waits for FTDI adapter via udev
#  • Rotates its own log
#  • Detects and maps FTDI to COM1, blocks COM2–COM20
#  • Adds alias sitrad4.13
#  • Launches SitradLocal.exe under Wine on DISPLAY=:1 (with /wait)
#  • Waits for the Sitrad window, sleeps for UI init, then sends Ctrl+L
###############################################################################

# ── 0) Ensure not root
[[ $EUID -eq 0 ]] && { echo "Run as normal user, not root."; exit 1; }

# ── 1) Prepare logging
LOG="$HOME/sitrad_setup.log"
# rotate if >128KiB
if [[ -f "$LOG" && $(stat -c%s "$LOG") -gt 131072 ]]; then
  mv -f "$LOG" "$LOG.$(date +%s)"
fi
exec > >(tee -a "$LOG") 2>&1

echo -e "\n$(date '+%F %T') — setup_sitrad.sh start\n"

# ── 2) Parse args
DEVICE_OVERRIDE=""
UNBLOCK=false
for arg in "$@"; do
  case $arg in
    --device=*) DEVICE_OVERRIDE="${arg#*=}" ;;
    --unblock)  UNBLOCK=true ;;
    *) echo "Unknown option: $arg" && exit 1 ;;
  esac
done

# ── 3) Variables
EXE="$HOME/.wine/drive_c/Program Files (x86)/Full Gauge/Sitrad/SitradLocal.exe"
DOS="$HOME/.wine/dosdevices"
ALIAS_CMD="alias sitrad4.13='wine start /wait \"$EXE\"'"

# ── 4) Unblock-only mode
if $UNBLOCK; then
  echo "Removing COM2–COM20 blockers..."
  find "$DOS" -maxdepth 1 \( -type d -name 'com[2-9]' -o -name 'com1[0-9]' \) \
        -print0 | xargs -0 -r rm -rf
  echo "All blockers removed. Exit."
  exit 0
fi

# ── 5) Detect FTDI adapter
echo "Detecting FTDI adapter:"
FTDI="$DEVICE_OVERRIDE"
for d in /dev/ttyUSB*; do
  [[ -e "$d" ]] || continue
  V=$(udevadm info -q property -n "$d" | awk -F= '/^ID_VENDOR=/ {print $2; exit}')
  M=$(udevadm info -q property -n "$d" | awk -F= '/^ID_MODEL=/ {print $2; exit}')
  printf "   → %-13s [%s / %s]\n" "$d" "${V:-unknown}" "${M:-unknown}"
  [[ $V == FTDI && -z $FTDI ]] && FTDI=$d
done
[[ -z $FTDI ]] && { echo "❌ No FTDI adapter found"; exit 1; }
echo -e "\nUsing $FTDI for COM1\n"

# ── 6) Block COM2–COM20
echo "Reserving COM2–COM20..."
find "$DOS" -maxdepth 1 -type l -name 'com*' -exec rm -f {} +
for n in {2..20}; do
  mkdir -p "$DOS/com$n" && chmod 000 "$DOS/com$n"
done

# ── 7) Map COM1
echo -e "\nMapping COM1 → $FTDI"
ln -sf "$FTDI" "$DOS/com1"
echo -e "\nCurrent Wine COM list:"
ls -ld "$DOS"/com* | sed 's/^/   /'

# ── 8) Add alias
grep -Fqx "$ALIAS_CMD" "$HOME/.bashrc" || echo "$ALIAS_CMD" >> "$HOME/.bashrc"

# ── 9) Launch Sitrad
export DISPLAY=:1
echo -e "\nLaunching Sitrad 4.13...\n"
wine "$EXE" &
WINE_PID=$!

# ── 10) Wait for Sitrad window + init
echo "Waiting for Sitrad window..."
until WID=$(xdotool search --name "Sitrad Local" 2>/dev/null | head -n1); do
  sleep 0.5
done

echo "Window detected (ID=$WID). Sleeping 30 s to finish loading..."
sleep 30

# ── 11) Send Ctrl+L
if xdotool windowactivate "$WID" && xdotool key --window "$WID" ctrl+l; then
  echo -e "\nCtrl+L sent. (PID=$WINE_PID)"
else
  echo -e "\nCould not auto-trigger communication, continuing..."
fi

# ── 12) Wait for Sitrad to exit
wait "$WINE_PID"
echo "Sitrad has exited (PID=$WINE_PID). Exiting setup_sitrad.sh."