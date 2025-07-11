#!/usr/bin/env bash
set -Eeuo pipefail
trap 'error_handler "$LINENO" "$BASH_COMMAND"' ERR

###############################################################################
# setup_sitrad.sh — Smart, refactored launcher for Sitrad 4.13 on ARM64
# • Waits for Xorg (dummy) session started via display.service
# • Detects FTDI adapter and maps to Wine COM1 via registry (reg)
# • Cleans old dosdevices links
# • Adds alias sitrad4.13 to .bashrc (BOX64 usage)
# • Launches SitradLocal.exe under Wine (Hangover and BOX64 emulator)
# • Sends Ctrl+L via send_ctrl_l_to_sitrad.sh (waiting the port or restart)
###############################################################################

# Ensure we are a normal user (not root)
[[ $EUID -eq 0 ]] && { echo "Run as normal user, not root."; exit 1; }

BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Wine paths ────────────────────────────────────────────────────────────────
EXE_DIR="$HOME/.wine/drive_c/Program Files (x86)/Full Gauge/Sitrad"
EXE_NAME="SitradLocal.exe"
EMULATOR_CMD="wine"
EXE_PATH="$EXE_DIR/$EXE_NAME"
DOS_DIR="$HOME/.wine/dosdevices"
BASHRC="$HOME/.bashrc"
DISPLAY_NUM=":1"
export DISPLAY="$DISPLAY_NUM"

# ── Logging utility ───────────────────────────────────────────────────────────
log() { echo -e "$(date '+%F %T') | $*" >&2; }

# ── Error handler ─────────────────────────────────────────────────────────────
error_handler() { log "ERROR at line $1: $2"; exit 1; }

# ── Check for required tools ──────────────────────────────────────────────────
check_dependencies() {
    local missing=()
    for cmd in wine udevadm xdotool ss; do
        command -v "$cmd" >/dev/null || missing+=("$cmd")
    done
    if (( ${#missing[@]} )); then
        log "Missing dependencies: ${missing[*]}"
        log "Please install: sudo apt install ${missing[*]} xserver-xorg-video-dummy"
        exit 1
    fi
}

# ── Wait for headless Xorg session ────────────────────────────────────────────
start_x_session() {
    log "Waiting for Xorg on $DISPLAY_NUM (started via display.service)…"
    until pgrep -f "Xorg $DISPLAY_NUM" >/dev/null; do
        sleep 0.5
    done
    log "Xorg session on $DISPLAY_NUM is ready"
}

# ── Detect FTDI adapter (USB-serial) ──────────────────────────────────────────
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

# ── Clear previous COM ports in dosdevices ────────────────────────────────────
clear_com_ports() {
    log "Clearing old COM links in $DOS_DIR"
    mkdir -p "$DOS_DIR"
    rm -rf "$DOS_DIR"/com*
}

# ── Map COM1 to the detected FTDI device via Wine registry ────────────────────
map_com1() {
    log "Mapping COM1 → $FTDI_DEVICE via Wine registry"
    wine reg add "HKLM\\Software\\Wine\\Ports" /f
    wine reg add "HKLM\\Software\\Wine\\Ports" /v COM1 /t REG_SZ /d "$FTDI_DEVICE" /f
}

# ── Add shell alias to launch Sitrad manually ─────────────────────────────────
add_alias() {
    unalias sitrad4.13 2>/dev/null || true
    local alias_cmd="alias sitrad4.13='pushd \"$EXE_DIR\" >/dev/null && $EMULATOR_CMD ./$EXE_NAME && popd >/dev/null'"
    grep -Fq 'alias sitrad4.13=' "$BASHRC" && sed -i '/alias sitrad4\.13=/d' "$BASHRC"
    echo "$alias_cmd" >> "$BASHRC"
    eval "$alias_cmd"
    log "Alias sitrad4.13 installed"
}

# ── Launch Sitrad via Wine on DISPLAY=:1 ──────────────────────────────────────
launch_sitrad() {
    log "Launching Sitrad 4.13 under Wine"
    pkill -f "$EXE_PATH" || true
    sleep 1
    pushd "$EXE_DIR" >/dev/null
    $EMULATOR_CMD "./$EXE_NAME" &
    WINE_PID=$!
    popd >/dev/null
}

# ── Wait for Sitrad window ────────────────────────────────────────────────────
wait_for_sitrad_window() {
    local timeout=60

    log "Waiting for 'Sitrad Local' window (max $timeout s)..."
    local start_time=$(date +%s)
    local wid

    while true; do
        wid=$(xdotool search --name "Sitrad Local" 2>/dev/null | head -n1 || true)
        [[ -n "$wid" ]] && echo "$wid" && return 0

        sleep 0.5

        local now=$(date +%s)
        if (( now - start_time >= timeout )); then
            log "Window not found after $timeout s"
            return 1
        fi
    done
}

# ── Send Ctrl+L and wait for FTDI device (single shot) ────────────────────────
send_ctrl_l_and_wait_port() {
    local wid=$1
    local sleep=90
    local timeout=60

    log "Window $wid detected — waiting $sleep s before Ctrl+L"
    sleep $sleep

    log "Sending Ctrl+L"
    if "$BASEDIR/send_ctrl_l_to_sitrad.sh" "$wid"; then
        log "Ctrl+L sent successfully"
    else
        log "Failed to send Ctrl+L - aborting and killing Wine"
        wineserver -k || true
        return
    fi

    log "Waiting up to $timeout s for $FTDI_DEVICE to open"
    if timeout $timeout bash -c "while ! fuser \"$FTDI_DEVICE\" &>/dev/null; do sleep 1; done"; then
        log "Device $FTDI_DEVICE opened by Sitrad"
    else
        log "Device $FTDI_DEVICE did not open within $timeout s - aborting and killing Wine"
        wineserver -k || true
        return
    fi
}

# ── Trigger Ctrl+L ────────────────────────────────────────────────────────────
trigger_ctrl_l() {
    local wid=$(wait_for_sitrad_window) || return 1
    send_ctrl_l_and_wait_port "$wid"
}

# ── Wait for Sitrad process to exit ───────────────────────────────────────────
wait_for_sitrad_exit() {
    wait "$WINE_PID" || true
    log "Sitrad exited (PID=$WINE_PID)"
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
    log "──────────────────────────────────────────────────────"
    log "Starting setup_sitrad.sh"
    check_dependencies
    start_x_session
    detect_ftdi
    clear_com_ports
    map_com1
    add_alias
    launch_sitrad
    trigger_ctrl_l
    wait_for_sitrad_exit
    log "──────────────────────────────────────────────────────"
    log "setup_sitrad.sh complete"
}

main "$@"
