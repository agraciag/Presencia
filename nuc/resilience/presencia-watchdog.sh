#!/usr/bin/env bash
# Presencia - Multi-level watchdog
# Monitors Chromium kiosk health and takes corrective actions.
# Runs as a system service triggered by a timer every 2 minutes.
set -euo pipefail

CONFIG="/opt/presencia/presencia.conf"
if [[ -f "$CONFIG" ]]; then
    source "$CONFIG"
fi

STATE_DIR="${PRESENCIA_STATE_DIR:-/var/lib/presencia}"
LOG_DIR="${PRESENCIA_LOG_DIR:-/var/log/presencia}"
NOTIFY="/opt/presencia/monitoring/presencia-notify.sh"
JITSI_DOMAIN="${JITSI_DOMAIN:-meet.example.com}"
REFRESH_HOURS="${WATCHDOG_REFRESH_HOURS:-6}"
PRESENCIA_USER="${PRESENCIA_USER:-presencia}"

LOGFILE="${LOG_DIR}/watchdog.log"
REFRESH_STAMP="${STATE_DIR}/last-refresh"
CURRENT_MODE="${STATE_DIR}/current-mode"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOGFILE"
}

notify() {
    if [[ -x "$NOTIFY" ]]; then
        "$NOTIFY" "$*" 2>/dev/null || true
    fi
}

# ─── Only run in telepresence mode ──────────────────────────────
if [[ -f "$CURRENT_MODE" ]]; then
    MODE="$(cat "$CURRENT_MODE")"
    if [[ "$MODE" != "telepresence" ]]; then
        exit 0
    fi
fi

PRESENCIA_UID="$(id -u "$PRESENCIA_USER" 2>/dev/null || echo "")"
if [[ -z "$PRESENCIA_UID" ]]; then
    log "ERROR: User $PRESENCIA_USER not found"
    exit 1
fi

# ─── Level 1: Check if Chromium is running ──────────────────────
if ! pgrep -u "$PRESENCIA_USER" -f "chromium.*--kiosk" &>/dev/null; then
    log "WARN: Chromium not running. Restarting kiosk service..."
    notify "⚠️ Chromium crashed. Restarting..."
    sudo -u "$PRESENCIA_USER" XDG_RUNTIME_DIR="/run/user/${PRESENCIA_UID}" \
        systemctl --user restart presencia-kiosk.service
    sleep 10

    if pgrep -u "$PRESENCIA_USER" -f "chromium.*--kiosk" &>/dev/null; then
        log "OK: Chromium restarted successfully."
        notify "✅ Chromium restarted successfully."
    else
        log "ERROR: Chromium failed to restart."
        notify "🔴 Chromium failed to restart!"
    fi
    exit 0
fi

# ─── Level 2: Check internet connectivity ──────────────────────
if ! ping -c 1 -W 5 8.8.8.8 &>/dev/null; then
    log "WARN: No internet connectivity."
    notify "⚠️ Internet disconnected."
    # Nothing to do here - systemd-networkd/NetworkManager will reconnect
    exit 0
fi

# ─── Level 2: Check Jitsi server reachable ──────────────────────
HTTP_CODE="$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "https://${JITSI_DOMAIN}" 2>/dev/null || echo "000")"
if [[ "$HTTP_CODE" != "200" ]]; then
    log "WARN: Jitsi server unreachable (HTTP ${HTTP_CODE}). Refreshing page..."
    notify "⚠️ Jitsi unreachable (HTTP ${HTTP_CODE}). Refreshing..."

    # Send F5 to Chromium to refresh
    sudo -u "$PRESENCIA_USER" DISPLAY=:0 xdotool key F5 2>/dev/null || true
    sleep 15

    # Verify again
    HTTP_CODE="$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "https://${JITSI_DOMAIN}" 2>/dev/null || echo "000")"
    if [[ "$HTTP_CODE" == "200" ]]; then
        log "OK: Jitsi reachable after refresh."
    else
        log "WARN: Jitsi still unreachable. Will retry on next cycle."
    fi
    exit 0
fi

# ─── Level 3: Check display is active ──────────────────────────
if ! sudo -u "$PRESENCIA_USER" DISPLAY=:0 xdpyinfo &>/dev/null 2>&1; then
    log "WARN: Display not responding. Restarting display manager..."
    notify "⚠️ Display frozen. Restarting lightdm..."
    systemctl restart lightdm
    sleep 15
    log "Display manager restarted."
    exit 0
fi

# ─── Preventive: Periodic refresh ──────────────────────────────
# Refresh Chromium every N hours to prevent memory leaks
if [[ ! -f "$REFRESH_STAMP" ]]; then
    date +%s > "$REFRESH_STAMP"
fi

LAST_REFRESH="$(cat "$REFRESH_STAMP")"
NOW="$(date +%s)"
ELAPSED=$(( (NOW - LAST_REFRESH) / 3600 ))

if [[ $ELAPSED -ge $REFRESH_HOURS ]]; then
    log "INFO: Preventive refresh (${ELAPSED}h since last refresh)."
    sudo -u "$PRESENCIA_USER" DISPLAY=:0 xdotool key F5 2>/dev/null || true
    date +%s > "$REFRESH_STAMP"
fi

log "OK: All checks passed."
