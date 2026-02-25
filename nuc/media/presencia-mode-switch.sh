#!/usr/bin/env bash
# Presencia - Mode switching orchestrator
# Switches between telepresence (Chromium kiosk) and media (Kodi) modes.
#
# Usage:
#   presencia-mode-switch.sh telepresence
#   presencia-mode-switch.sh media
#   presencia-mode-switch.sh status
set -euo pipefail

CONFIG="/opt/presencia/presencia.conf"
if [[ -f "$CONFIG" ]]; then
    source "$CONFIG"
fi

STATE_DIR="${PRESENCIA_STATE_DIR:-/var/lib/presencia}"
LOG_DIR="${PRESENCIA_LOG_DIR:-/var/log/presencia}"
NOTIFY="/opt/presencia/monitoring/presencia-notify.sh"
PRESENCIA_USER="${PRESENCIA_USER:-presencia}"

CURRENT_MODE_FILE="${STATE_DIR}/current-mode"
LOGFILE="${LOG_DIR}/mode-switch.log"

PRESENCIA_UID="$(id -u "$PRESENCIA_USER" 2>/dev/null || echo "")"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOGFILE"
}

notify() {
    if [[ -x "$NOTIFY" ]]; then
        "$NOTIFY" "$*" 2>/dev/null || true
    fi
}

user_systemctl() {
    sudo -u "$PRESENCIA_USER" XDG_RUNTIME_DIR="/run/user/${PRESENCIA_UID}" \
        systemctl --user "$@"
}

get_current_mode() {
    if [[ -f "$CURRENT_MODE_FILE" ]]; then
        cat "$CURRENT_MODE_FILE"
    else
        echo "unknown"
    fi
}

stop_telepresence() {
    log "Stopping telepresence services..."
    user_systemctl stop presencia-kiosk.service 2>/dev/null || true
    # Give Chromium time to shut down cleanly
    sleep 2
    pkill -u "$PRESENCIA_USER" -f "chromium" 2>/dev/null || true
}

start_telepresence() {
    log "Starting telepresence services..."
    # Ensure Kodi is stopped
    systemctl stop kodi-autostart.service 2>/dev/null || true
    pkill -u "$PRESENCIA_USER" -f "kodi" 2>/dev/null || true
    sleep 1

    user_systemctl start presencia-kiosk.service
    user_systemctl start presencia-cec.service 2>/dev/null || true
}

stop_media() {
    log "Stopping media services..."
    systemctl stop kodi-autostart.service 2>/dev/null || true
    pkill -u "$PRESENCIA_USER" -f "kodi" 2>/dev/null || true
}

start_media() {
    log "Starting media services..."
    # Ensure Chromium is stopped
    user_systemctl stop presencia-kiosk.service 2>/dev/null || true
    pkill -u "$PRESENCIA_USER" -f "chromium" 2>/dev/null || true
    sleep 1

    systemctl start kodi-autostart.service
}

TARGET="${1:-status}"

case "$TARGET" in
    telepresence)
        CURRENT="$(get_current_mode)"
        if [[ "$CURRENT" == "telepresence" ]]; then
            log "Already in telepresence mode."
            exit 0
        fi

        log "Switching to TELEPRESENCE mode (from ${CURRENT})..."
        notify "🔄 Switching to telepresence mode..."

        stop_media
        start_telepresence

        echo "telepresence" > "$CURRENT_MODE_FILE"
        log "Mode switched to TELEPRESENCE."
        notify "📹 Telepresence mode active."
        ;;

    media)
        CURRENT="$(get_current_mode)"
        if [[ "$CURRENT" == "media" ]]; then
            log "Already in media mode."
            exit 0
        fi

        log "Switching to MEDIA mode (from ${CURRENT})..."
        notify "🔄 Switching to media mode..."

        stop_telepresence
        start_media

        echo "media" > "$CURRENT_MODE_FILE"
        log "Mode switched to MEDIA."
        notify "🎬 Media mode active (Kodi)."
        ;;

    status)
        echo "Current mode: $(get_current_mode)"
        ;;

    *)
        echo "Usage: $0 {telepresence|media|status}"
        exit 1
        ;;
esac
