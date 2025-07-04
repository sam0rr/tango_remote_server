#!/usr/bin/env bash
set -Eeuo pipefail
trap 'error_handler "$LINENO" "$BASH_COMMAND"' ERR

###############################################################################
# watchdog.sh — Monitors USB and telemetry logs to auto-recover Sitrad
# • Detects FTDI disconnections (kernel USB errors)
# • Detects 4 consecutive empty telemetry cycles via [TELEMETRY_START]/[NO_DATA]
# • Triggers Wine reset via wineserver -k
###############################################################################

# ── Configuration ─────────────────────────────────────────────────────────────
FTDI_MATCH="ftdi.*disconnected"
TELEMETRY_UNIT="send_to_tb.service"
TELEMETRY_START_PATTERN="[TELEMETRY_START]"
NO_DATA_PATTERN="[NO_DATA]"
MAX_EMPTY_CYCLES=4

# ── Logging utility ───────────────────────────────────────────────────────────
log() { echo -e "$(date '+%F %T') | $*" >&2; }

# ── Error handler ─────────────────────────────────────────────────────────────
error_handler() { log "ERROR at line $1: $2"; exit 1; }

# ── Trigger Wine recovery ─────────────────────────────────────────────────────
trigger_recovery() {
    log "Triggering Wine recovery via wineserver -k"
    wineserver -k || true
}

# ── Monitor dmesg/journal for USB disconnects ─────────────────────────────────
monitor_usb_disconnects() {
    journalctl -kf |
    grep --line-buffered "$FTDI_MATCH" |
    while IFS= read -r line; do
        log "USB disconnect detected: $line"
        trigger_recovery
    done
}

# ── Monitor telemetry logs for 4 consecutive [NO_DATA] cycles ─────────────────
monitor_empty_telemetry_cycles() {
    local empty_count=0
    local in_cycle=false
    local has_no_data=false

    journalctl --user -fu "$TELEMETRY_UNIT" --output=cat --lines=0 |
    while IFS= read -r line; do
        case "$line" in
            *"$TELEMETRY_START_PATTERN"*)
                if $in_cycle; then
                    handle_cycle_result "$has_no_data" empty_count
                fi
                in_cycle=true
                has_no_data=false
                ;;
            *"$NO_DATA_PATTERN"*)
                $in_cycle && has_no_data=true
                ;;
        esac
    done
}

# ── Handle end of telemetry cycle ─────────────────────────────────────────────
handle_cycle_result() {
    local was_empty=$1
    local -n count_ref=$2 

    if $was_empty; then
        count_ref=$((count_ref + 1))
        log "Empty telemetry cycle ($count_ref/$MAX_EMPTY_CYCLES)"
    else
        count_ref=0
    fi

    if [[ $count_ref -ge $MAX_EMPTY_CYCLES ]]; then
        log "$MAX_EMPTY_CYCLES consecutive empty telemetry cycles — triggering recovery"
        trigger_recovery
        count_ref=0
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
