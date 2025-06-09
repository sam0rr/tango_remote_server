#!/usr/bin/env bash
set -Eeuo pipefail
trap 'error_handler "$LINENO" "$BASH_COMMAND"' ERR

###############################################################################
# setup_sitrad.sh — Smart, refactored launcher for Sitrad 4.13 on Raspberry Pi
# • Starts Xvfb + Openbox (headless GUI)
# • Detects FTDI adapter and maps to Wine COM1
# • Blocks COM2–COM20 to prevent Wine conflicts
# • Adds alias sitrad4.13
# • Launches SitradLocal.exe under Wine
# • Sends Ctrl+L to trigger Sitrad connection
###############################################################################

# Ensure we are a normal user (not root)
[[ $EUID -eq 0 ]] && { echo "Run as normal user, not root."; exit 1; }

BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOGFILE="$HOME/sitrad_setup.log"
EXE_PATH="$HOME/.wine/drive_c/Program Files (x86)/Full Gauge/Sitrad/SitradLocal.exe"
DOS_DIR="$HOME/.wine/dosdevices"
BASHRC="$HOME/.bashrc"
DEVICE=""
UNBLOCK=false

# ── Logging utility ──────────────────────────────────────────────────────────
log() {
    echo -e "$(date '+%F %T') | $*"
}

# ── Error handler ─────────────────────────────────────────────────────────────
error_handler() {
    log "ERROR at line $1: $2"
    exit 1
}

# ── Rotate logs if >128 KB ────────────────────────────────────────────────────
rotate_logs() {
    local max_size=131072
    [[ -f $LOGFILE && $(stat -c%s "$LOGFILE") -gt $max_size ]] &&
        mv -f "$LOGFILE" "$LOGFILE.$(date +%s)"
}

# ── Parse command-line arguments ──────────────────────────────────────────────
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --device=*) DEVICE="${1#*=}"; shift ;;
            --unblock) UNBLOCK=true; shift ;;
            *) log "Unknown option: $1"; exit 1 ;;
        esac
    done
}

# ── Start headless X session with Openbox ─────────────────────────────────────
start_x_session() {
    log "Launching Xvfb + Openbox on :1"
    nohup Xvfb :1 -screen 0 1024x768x16 -ac >/dev/null 2>&1 &
    sleep 1
    nohup openbox --display :1 >/dev/null 2>&1 &
    sleep 1
    mkdir -p "$DOS_DIR"
}

# ── Remove reserved COM ports (used with --unblock) ─────────────────────────--
unblock_ports() {
    log "Removing COM2–COM20 blockers"
    find "$DOS_DIR" -maxdepth 1 \(
        -type d -name 'com[2-9]' -o -name 'com1[0-9]' \) -print0 |
        xargs -0 -r rm -rf
}

# ── Detect FTDI adapter (USB-serial) ──────────────────────────────────────────
detect_ftdi() {
    if [[ -n $DEVICE ]]; then
        FTDI_DEVICE="$DEVICE"
    else
        log "Detecting FTDI adapter..."
        for dev in /dev/ttyUSB*; do
            [[ -e $dev ]] || continue
            local vendor model
            vendor=$(udevadm info -q property -n "$dev" | grep -m1 '^ID_VENDOR=' | cut -d= -f2 || true)
            model=$(udevadm info -q property -n "$dev" | grep -m1 '^ID_MODEL=' | cut -d= -f2 || true)
            printf "   → %-12s [%s/%s]\n" "$dev" "${vendor:-unknown}" "${model:-unknown}"
            [[ $vendor == FTDI ]] && FTDI_DEVICE="$dev"
        done
    fi
    [[ -z ${FTDI_DEVICE:-} ]] && { log "❌ No FTDI adapter found"; exit 1; }
    log "Using $FTDI_DEVICE as COM1"
}

# ── Block COM2–COM20 to prevent Wine from auto-mapping ───────────────────────
block_ports() {
    log "Blocking COM2–COM20"
    find "$DOS_DIR" -maxdepth 1 -type l -name 'com*' -exec rm -f {} +
    for n in {2..20}; do
        mkdir -p "$DOS_DIR/com$n" && chmod 000 "$DOS_DIR/com$n"
    done
}

# ── Link COM1 to the detected FTDI device ─────────────────────────────────────
map_com1() {
    log "Mapping COM1 → $FTDI_DEVICE"
    ln -sf "$FTDI_DEVICE" "$DOS_DIR/com1"
}

# ── Add a shell alias to easily launch Sitrad manually ───────────────────────
add_alias() {
    local alias_cmd="alias sitrad4.13='wine \"$EXE_PATH\"'"
    if ! grep -Fxq "$alias_cmd" "$BASHRC"; then
        log "Adding alias to ~/.bashrc"
        echo "$alias_cmd" >> "$BASHRC"
    fi
}

# ── Launch Sitrad via Wine on DISPLAY=:1 ──────────────────────────────────────
launch_sitrad() {
    log "Launching Sitrad 4.13 under Wine"
    DISPLAY=:1 wine "$EXE_PATH" &
    WINE_PID=$!
}

# ── Wait for Sitrad window and send Ctrl+L ────────────────────────────────────
trigger_ctrl_l() {
    log "Waiting for Sitrad window…"
    local wid
    until wid=$(xdotool search --name "Sitrad Local" 2>/dev/null | head -n1); do
        sleep 0.5
    done
    log "Window $wid detected — waiting 30s"
    sleep 30
    if "$BASEDIR/send_ctrl_l_to_sitrad.sh"; then
        log "Ctrl+L sent successfully"
    else
        log "Could not send Ctrl+L"
    fi
    wait "$WINE_PID"
    log "Sitrad exited (PID=$WINE_PID)"
}

# ── Main ────────────────────────────────────────────────────────────
main() {
    rotate_logs
    exec > >(tee -a "$LOGFILE") 2>&1
    log "Starting setup_sitrad.sh"
    parse_args "$@"
    start_x_session
    if $UNBLOCK; then
        unblock_ports
        exit 0
    fi
    detect_ftdi
    block_ports
    map_com1
    add_alias
    launch_sitrad
    trigger_ctrl_l
}

main "$@"