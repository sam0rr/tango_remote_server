#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "Error line $LINENO: $BASH_COMMAND" >&2' ERR

###############################################################################
#  setup_sitrad.sh — Smart launcher for Sitrad 4.13 on Raspberry Pi (headless)
#  • Starts Xvfb + Openbox
#  • Detects the FTDI adapter and maps it to COM1
#  • Blocks COM2-COM20 (or --unblock)
#  • Adds alias sitrad4.13
#  • Launches SitradLocal.exe under Wine on DISPLAY=:1
###############################################################################

# make sure we run under a normal user
[[ $EUID -eq 0 ]] && { echo "Run as normal user, not root."; exit 1; }

LOG="$HOME/sitrad_setup.log"
EXE="$HOME/.wine/drive_c/Program Files (x86)/Full Gauge/Sitrad/SitradLocal.exe"
DOS="$HOME/.wine/dosdevices"
ALIAS_CMD="alias sitrad4.13='wine \"$EXE\"'"
BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DEVICE_OVERRIDE=""
UNBLOCK=false
for arg in "$@"; do
  case $arg in
    --device=*) DEVICE_OVERRIDE="${arg#*=}" ;;
    --unblock)  UNBLOCK=true ;;
    *) echo "Unknown option: $arg" && exit 1 ;;
  esac
done

# rotate logs if >128 KB
[[ -f $LOG && $(stat -c%s "$LOG") -gt 131072 ]] && mv -f "$LOG" "$LOG.$(date +%s)"
exec > >(tee -a "$LOG") 2>&1

echo -e "\n$(date '+%F %T') — setup_sitrad.sh (headless) start\n"

# ── 1) Start headless X session ────────────────────────────────────────────────
echo ">>> Launching Xvfb + Openbox on :1"
nohup Xvfb :1 -screen 0 1024x768x16 -ac >/dev/null 2>&1 &
sleep 1
nohup openbox --display :1 >/dev/null 2>&1 &
sleep 1

mkdir -p "$DOS"

# ── 2) Unblock-only mode? ───────────────────────────────────────────────────────
if $UNBLOCK; then
  echo "Removing COM2-COM20 blockers…"
  find "$DOS" -maxdepth 1 \( -type d -name 'com[2-9]' -o -name 'com1[0-9]' \) \
        -print0 | xargs -0 -r rm -rf
  echo "All blockers removed. Exit."
  exit 0
fi

# ── 3) Detect FTDI adapter ─────────────────────────────────────────────────────
echo "Detecting FTDI adapter:"
FTDI="$DEVICE_OVERRIDE"
if [[ -z $FTDI ]]; then
  for d in /dev/ttyUSB*; do
    [[ -e $d ]] || continue
    V=$(udevadm info -q property -n "$d" | grep -m1 '^ID_VENDOR=' | cut -d= -f2 || true)
    M=$(udevadm info -q property -n "$d" | grep -m1 '^ID_MODEL='  | cut -d= -f2 || true)
    printf "   → %-13s [%s / %s]\n" "$d" "${V:-unknown}" "${M:-unknown}"
    [[ $V == FTDI && -z $FTDI ]] && FTDI=$d
  done
fi
[[ -z $FTDI ]] && { echo "❌  No FTDI adapter found"; exit 1; }
echo -e "\nUsing $FTDI for COM1\n"

# ── 4) Block COM2-COM20 ────────────────────────────────────────────────────────
find "$DOS" -maxdepth 1 -type l -name 'com*' -exec rm -f {} +
echo "Reserving COM2-COM20…"
for n in {2..20}; do
  mkdir -p "$DOS/com$n" && chmod 000 "$DOS/com$n"
done

# ── 5) Map COM1 ────────────────────────────────────────────────────────────────
echo -e "\nMapping COM1 → $FTDI"
ln -sf "$FTDI" "$DOS/com1"

echo -e "\nCurrent Wine COM list:"
for f in "$DOS"/com*; do ls -ld "$f"; done | sed 's/^/   /'

# ── 6) Add alias ───────────────────────────────────────────────────────────────
grep -Fqx "$ALIAS_CMD" "$HOME/.bashrc" 2>/dev/null || echo "$ALIAS_CMD" >> "$HOME/.bashrc"

# ── 7) Launch Sitrad under Wine ────────────────────────────────────────────────
export DISPLAY=:1
echo -e "\nLaunching Sitrad 4.13…\n"
wine "$EXE" &
WINE_PID=$!

# ── 8) Wait for window, then auto-trigger Ctrl+L ────────────────────────────────
echo "Waiting for Sitrad window…"
while ! WID=$(xdotool search --name "Sitrad Local" 2>/dev/null | head -n1); do
  sleep 0.5
done

echo "Window detected (ID=$WID). Sleeping 30 seconds to let UI finish loading…"
sleep 30

# send Ctrl+L
"$BASEDIR/send_ctrl_l_to_sitrad.sh" || echo "Could not auto-trigger communication"

echo -e "\nCtrl+L sent. Now waiting for Sitrad process (PID=$WINE_PID)…"
wait "$WINE_PID"
echo "Sitrad has exited (PID=$WINE_PID). Exiting setup_sitrad.sh."
