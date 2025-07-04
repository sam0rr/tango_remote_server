#!/usr/bin/env bash
set -Eeuo pipefail
trap 'error_handler "$LINENO" "$BASH_COMMAND"' ERR

###############################################################################
# send_ctrl_l_to_sitrad.sh — Script to focus Sitrad and send Ctrl+L
# • Ensures correct DISPLAY is used
# • Uses provided window ID or detects the Sitrad window via xdotool
# • Focuses the window and sends Ctrl+L
###############################################################################

# ── Configuration variables ───────────────────────────────────────────────────
WINDOW_NAME="${WINDOW_NAME:-Sitrad Local}"
DISPLAY_VAL="${DISPLAY_VAL:-:1}"

# ── Logging utility ───────────────────────────────────────────────────────────
log() { echo -e "$(date '+%F %T') | $*" >&2; }

# ── Error handler ─────────────────────────────────────────────────────────────
error_handler() { log "ERROR at line $1: $2"; exit 1; }

# ── Prepare DISPLAY environment ───────────────────────────────────────────────
prepare_display() {
    log "Using DISPLAY=$DISPLAY_VAL"
    export DISPLAY="$DISPLAY_VAL"
}

# ── Search for the Sitrad window ──────────────────────────────────────────────
get_window_id() {
    log "Searching for window \"$WINDOW_NAME\""
    local wid
    wid=$(xdotool search --onlyvisible --name "$WINDOW_NAME" 2>/dev/null | head -n1 || true)
    if [[ -z "$wid" ]]; then
        log "Window '$WINDOW_NAME' not found"
        exit 1
    fi
    log "Found window ID: $wid"
    echo "$wid"
}

# ── Focus the Sitrad window ───────────────────────────────────────────────────
focus_window() {
    local wid="$1"
    xdotool windowmap "$wid" 2>/dev/null || log "Could not map window $wid (may already be mapped)"
    sleep 0.1
    xdotool windowfocus "$wid"
    sleep 0.2
}

# ── Send Ctrl+L keystroke to the window ───────────────────────────────────────
send_ctrl_l() {
    local wid="$1"
    log "Sending Ctrl+L to window $wid"
    xdotool key --window "$wid" ctrl+l
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
    prepare_display

    local window_id="${1:-}"
    if [[ -n "$window_id" ]]; then
        log "Using provided window ID: $window_id"
    else
        window_id=$(get_window_id)
    fi

    focus_window "$window_id"
    send_ctrl_l   "$window_id"
}

main "$@"
