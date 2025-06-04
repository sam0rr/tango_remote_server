#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "❌  Error line $LINENO: $BASH_COMMAND" >&2' ERR

###############################################################################
#  setup_sitrad.sh — Smart launcher for Sitrad 4.13 on Raspberry Pi
#  • Détecte l’adaptateur FTDI et le mappe sur COM1
#  • Bloque COM2-COM20 (ou les débloque avec --unblock)
#  • Ajoute l’alias « sitrad4.13 »
#  • Lance SitradLocal.exe
#
#  Options :
#     --device=/dev/ttyUSBx   force le port RS-485
#     --unblock               supprime les répertoires COM2-COM20 puis quitte
###############################################################################

[[ $EUID -eq 0 ]] && { echo "❌  Run as normal user, not root."; exit 1; }

LOG="$HOME/sitrad_setup.log"
EXE="$HOME/.wine/drive_c/Program Files (x86)/Full Gauge/Sitrad/SitradLocal.exe"
DOS="$HOME/.wine/dosdevices"
ALIAS_CMD="alias sitrad4.13='wine \"$EXE\"'"

DEVICE_OVERRIDE=""
UNBLOCK=false
for arg in "$@"; do
  case $arg in
    --device=*) DEVICE_OVERRIDE="${arg#*=}" ;;
    --unblock)  UNBLOCK=true ;;
    *) echo "Unknown option: $arg" && exit 1 ;;
  esac
done

# ── rotation du log ──────────────────────────────────────────────────────────
[[ -f $LOG && $(stat -c%s "$LOG") -gt 131072 ]] && mv -f "$LOG" "$LOG.$(date +%s)"
exec > >(tee -a "$LOG") 2>&1
echo -e "\n$(date '+%F %T') — setup_sitrad.sh start\n"

mkdir -p "$DOS"

# ── mode unblock seul ────────────────────────────────────────────────────────
if $UNBLOCK; then
  echo "🧹  Removing COM2-COM20 blockers…"
  find "$DOS" -maxdepth 1 \( -type d -name 'com[2-9]' -o -name 'com1[0-9]' \) \
        -print0 | xargs -0 -r rm -rf
  echo "✅  All blockers removed. Exit."
  exit 0
fi

# ── détection de l’adaptateur FTDI ───────────────────────────────────────────
echo "🔍 Detecting FTDI adapter:"
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
echo -e "\n✅  Using $FTDI for COM1\n"

# ── nettoyage des anciens symlinks ───────────────────────────────────────────
find "$DOS" -maxdepth 1 -type l -name 'com*' -exec rm -f {} +

# ── blocage COM2-COM20 ───────────────────────────────────────────────────────
echo "🔒 Reserving COM2-COM20…"
for n in {2..20}; do
  mkdir -p "$DOS/com$n" && chmod 000 "$DOS/com$n"
done

# ── mapping COM1 ─────────────────────────────────────────────────────────────
echo -e "\n🔗 Mapping COM1 → $FTDI"
ln -sf "$FTDI" "$DOS/com1"

# ── état courant ─────────────────────────────────────────────────────────────
echo -e "\n📋 Current Wine COM list:"
for f in "$DOS"/com*; do ls -ld "$f"; done | sed 's/^/   /'

# ── ajout de l’alias bash ────────────────────────────────────────────────────
grep -Fqx "$ALIAS_CMD" "$HOME/.bashrc" 2>/dev/null || echo "$ALIAS_CMD" >> "$HOME/.bashrc"

# ── lancement de Sitrad ──────────────────────────────────────────────────────
echo -e "\n🚀  Launching Sitrad 4.13…\n"
wine "$EXE"

echo -e "\n✅  Sitrad exited. All done."
