#!/usr/bin/env bash
set -Eeuo pipefail
trap 'error_handler "$LINENO" "$BASH_COMMAND"' ERR

###############################################################################
# watchdog.sh — Monitors USB and telemetry logs to auto-recover Sitrad
# • Detects FTDI disconnections (kernel USB errors)
# • Detects consecutive empty telemetry cycles via [TELEMETRY_START]/[NO_DATA]/[TELEMETRY_DONE]
# • Triggers Wine reset via wineserver -k (restart Sitrad)
###############################################################################

# ── Configuration ─────────────────────────────────────────────────────────────
FTDI_MATCH="ftdi.*disconnected"
TELEMETRY_UNIT="send_to_tb.service"
TELEMETRY_START_PATTERN="[TELEMETRY_START]"
NO_DATA_PATTERN="[NO_DATA]"
TELEMETRY_DONE_PATTERN="[TELEMETRY_DONE]"
MAX_EMPTY_CYCLES=20
RESET_FLAG_FILE="/tmp/watchdog_reset"

# ── Logging utility ───────────────────────────────────────────────────────────
log() { echo -e "$(date '+%F %T') | $*" >&2; }

# ── Error handler ─────────────────────────────────────────────────────────────
error_handler() { log "ERROR at line $1: $2"; exit 1; }

# ── Trigger Wine recovery ─────────────────────────────────────────────────────
trigger_recovery() {
    log "Triggering Wine recovery via wineserver -k"
    wineserver -k || true
    log "Flagging telemetry counter reset"
    touch "$RESET_FLAG_FILE"
}

# ── Monitor dmesg/journal for USB disconnects ─────────────────────────────────
monitor_usb_disconnects() {
    journalctl -kf |
    grep --line-buffered "$FTDI_MATCH" |
    while IFS= read -r line; do
        log "USB disconnect detected: $line — triggering recovery"
        trigger_recovery
    done
}

# ── Monitor telemetry logs with TELEMETRY_DONE trigger ────────────────────────
monitor_empty_telemetry_cycles() {
    local in_cycle=false
    local is_empty=false
    local empty_count=0

    journalctl --user -fu "$TELEMETRY_UNIT" --output=cat --lines=0 |
    while IFS= read -r line; do

        if [[ -f "$RESET_FLAG_FILE" ]]; then
            empty_count=0
            rm -f "$RESET_FLAG_FILE"
            log "Reset flag detected — telemetry counter reset"
        fi

        case "$line" in
            *"$TELEMETRY_START_PATTERN"*)
                in_cycle=true
                is_empty=false
                ;;
            *"$NO_DATA_PATTERN"*)
                $in_cycle && is_empty=true
                ;;
            *"$TELEMETRY_DONE_PATTERN"*)
                if $in_cycle; then
                    handle_cycle_result "$is_empty" empty_count
                    in_cycle=false
                fi
                ;;
        esac
    done
}

# ── Handle end of telemetry cycle ─────────────────────────────────────────────
handle_cycle_result() {
    local is_empty=$1
    local -n empty_count=$2

    if $is_empty; then
        empty_count=$((empty_count + 1))
        log "Empty telemetry cycle ($empty_count/$MAX_EMPTY_CYCLES)"
    else
        empty_count=0
        log "Telemetry cycle had data — empty counter reset"
    fi

    if [[ $empty_count -ge $MAX_EMPTY_CYCLES ]]; then
        log "$MAX_EMPTY_CYCLES consecutive empty telemetry cycles — triggering recovery"
        trigger_recovery
    fi
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
    log "Watchdog started — monitoring USB and telemetry logs"
    monitor_usb_disconnects &
    monitor_empty_telemetry_cycles &
    wait -n
}

main "$@"
