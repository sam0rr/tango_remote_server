#!/usr/bin/env bash
set -Eeuo pipefail
trap 'error_handler "$LINENO" "$BASH_COMMAND"' ERR

###############################################################################
# setup_sitrad.sh — Smart, refactored launcher for Sitrad 4.13 on Raspberry Pi
# • Starts Xorg (dummy) for headless GUI
# • Detects FTDI adapter and maps to Wine COM1
# • Blocks COM2–COM20 to prevent Wine conflicts
# • Adds alias sitrad4.13 to .bashrc
# • Launches SitradLocal.exe under Wine
# • Sends Ctrl+L via send_ctrl_l_to_sitrad.sh
###############################################################################

# Ensure we are a normal user (not root)
[[ $EUID -eq 0 ]] && { echo "Run as normal user, not root."; exit 1; }

BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Wine paths ────────────────────────────────────────────────────────────────
EXE_DIR="$HOME/.wine/drive_c/Program Files/Full Gauge/Sitrad"
EXE_NAME="SitradLocal.exe"
EXE_PATH="$EXE_DIR/$EXE_NAME"

DOS_DIR="$HOME/.wine/dosdevices"
BASHRC="$HOME/.bashrc"
DISPLAY_NUM=":1"
export DISPLAY="$DISPLAY_NUM"
export XAUTHORITY="$HOME/.Xauthority"

# ── Logging utility ───────────────────────────────────────────────────────────
log() { echo -e "$(date '+%F %T') | $*"; }

# ── Error handler ─────────────────────────────────────────────────────────────
error_handler() { log "ERROR at line $1: $2"; exit 1; }

# ── Check for required tools ─────────────────────────────────────────────────
check_dependencies() {
    local missing=()
    for cmd in wine Xorg udevadm xdotool ss; do
        command -v "$cmd" >/dev/null || missing+=("$cmd")
    done
    if (( ${#missing[@]} )); then
        log "Missing dependencies: ${missing[*]}"
        log "Please install: sudo apt install ${missing[*]} xserver-xorg-video-dummy"
        exit 1
    fi
}

# ── Start headless Xorg ───────────────────────────────────────────────────────
start_x_session() {
    log "Launching Xorg (dummy) on $DISPLAY_NUM"
    if ! pgrep -f "Xorg $DISPLAY_NUM" >/dev/null; then
        Xorg $DISPLAY_NUM \
            -config /etc/X11/xorg.conf.d/10-dummy.conf \
            -nolisten tcp vt7 &
        sleep 2
    else
        log "Xorg already running"
    fi
    mkdir -p "$DOS_DIR"
}

# ── Detect FTDI adapter (USB-serial) ─────────────────────────────────────────
detect_ftdi() {
    log "Detecting FTDI adapter..."
    for dev in /dev/ttyUSB*; do
        [[ -e $dev ]] || continue
        local vendor
        vendor=$(udevadm info -q property -n "$dev" | grep -m1 '^ID_VENDOR=' | cut -d= -f2 || true)
        [[ $vendor == FTDI ]] && { FTDI_DEVICE="$dev"; break; }
    done
    [[ -z ${FTDI_DEVICE:-} ]] && { log "No FTDI adapter found"; exit 1; }
    log "Using $FTDI_DEVICE as COM1"
}

# ── Block COM2–COM20 to prevent Wine auto-mapping ─────────────────────────────
block_ports() {
    log "Blocking COM2–COM20"
    find "$DOS_DIR" -maxdepth 1 -type l -name 'com*' -exec rm -f {} +
    for n in {2..20}; do
        mkdir -p "$DOS_DIR/com$n" && chmod 000 "$DOS_DIR/com$n"
    done
}

# ── Link COM1 to the detected FTDI device ────────────────────────────────────
map_com1() {
    log "Mapping COM1 → $FTDI_DEVICE"
    ln -sf "$FTDI_DEVICE" "$DOS_DIR/com1"
}

# ── Add shell alias to launch Sitrad manually ────────────────────────────────
add_alias() {
    unalias sitrad4.13 2>/dev/null || true
    local alias_cmd="alias sitrad4.13='pushd \"$EXE_DIR\" >/dev/null && wine ./$EXE_NAME && popd >/dev/null'"
    grep -Fq 'alias sitrad4.13=' "$BASHRC" && sed -i '/alias sitrad4\.13=/d' "$BASHRC"
    echo "$alias_cmd" >> "$BASHRC"
    eval "$alias_cmd"
    log "Alias sitrad4.13 installed"
}

# ── Launch Sitrad via Wine on DISPLAY=:1 ─────────────────────────────────────
launch_sitrad() {
    log "Launching Sitrad 4.13 under Wine"
    pkill -f "$EXE_PATH" || true
    sleep 1
    pushd "$EXE_DIR" >/dev/null
    wine "./$EXE_NAME" &
    WINE_PID=$!
    popd >/dev/null
}

# ── Wait for Sitrad window and send Ctrl+L ────────────────────────────────────
trigger_ctrl_l() {
    log "Waiting for 'Sitrad Local' window (max 60s)..."
    local wid=""
    for i in {1..120}; do
        wid=$(xdotool search --name "Sitrad Local" 2>/dev/null | head -n1 || true)
        [[ -n "$wid" ]] && break
        sleep 0.5
    done

    if [[ -z "$wid" ]]; then
        log "Window 'Sitrad Local' not detected after 60s"
        return
    fi

    log "Window $wid detected — waiting 45 s"
    sleep 45
    if "$BASEDIR/send_ctrl_l_to_sitrad.sh" "$wid"; then
        log "Ctrl+L sent to window $wid"
    else
        log "Failed to send Ctrl+L"
    fi

    wait "$WINE_PID"
    log "Sitrad exited (PID=$WINE_PID)"
}

main() {
    log "──────────────────────────────────────────────────────"
    log "Starting setup_sitrad.sh"
    check_dependencies
    start_x_session
    detect_ftdi
    block_ports
    map_com1
    add_alias
    launch_sitrad
    trigger_ctrl_l
    log "──────────────────────────────────────────────────────"
    log "setup_sitrad.sh complete"
}

main "$@"
