#!/usr/bin/env bash
# Presencia - Periodic health monitoring report
# Sends a status summary to Telegram every 15 minutes.
set -euo pipefail

CONFIG="/opt/presencia/presencia.conf"
if [[ -f "$CONFIG" ]]; then
    source "$CONFIG"
fi

STATE_DIR="${PRESENCIA_STATE_DIR:-/var/lib/presencia}"
LOG_DIR="${PRESENCIA_LOG_DIR:-/var/log/presencia}"
NOTIFY="/opt/presencia/monitoring/presencia-notify.sh"
PRESENCIA_USER="${PRESENCIA_USER:-presencia}"
JITSI_DOMAIN="${JITSI_DOMAIN:-meet.example.com}"

PRESENCIA_UID="$(id -u "$PRESENCIA_USER" 2>/dev/null || echo "")"

# ─── Gather metrics ────────────────────────────────────────────
MODE="unknown"
if [[ -f "${STATE_DIR}/current-mode" ]]; then
    MODE="$(cat "${STATE_DIR}/current-mode")"
fi

UPTIME="$(uptime -p | sed 's/up //')"
LOAD="$(cat /proc/loadavg | awk '{print $1}')"
MEM_PERCENT="$(free | awk '/^Mem:/{printf "%.0f", $3/$2*100}')"
DISK_PERCENT="$(df / | awk 'NR==2{print $5}')"
TEMP="$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null | awk '{printf "%.0f", $1/1000}' || echo 'N/A')"

# Internet check
INTERNET="✅"
if ! ping -c 1 -W 3 8.8.8.8 &>/dev/null; then
    INTERNET="❌"
fi

# Jitsi check
JITSI="✅"
HTTP_CODE="$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "https://${JITSI_DOMAIN}" 2>/dev/null || echo "000")"
if [[ "$HTTP_CODE" != "200" ]]; then
    JITSI="❌ (${HTTP_CODE})"
fi

# Kiosk check
KIOSK="N/A"
if [[ "$MODE" == "telepresence" ]]; then
    if pgrep -u "$PRESENCIA_USER" -f "chromium.*--kiosk" &>/dev/null; then
        KIOSK="✅"
    else
        KIOSK="❌"
    fi
fi

# Tailscale
TAILSCALE="✅"
if ! tailscale status &>/dev/null 2>&1; then
    TAILSCALE="❌"
fi

# ─── Build report ──────────────────────────────────────────────
REPORT="📊 *Status Report*
Mode: \`${MODE}\`
Uptime: ${UPTIME}
Load: ${LOAD} | Mem: ${MEM_PERCENT}% | Disk: ${DISK_PERCENT} | Temp: ${TEMP}°C
Internet: ${INTERNET} | Jitsi: ${JITSI} | Tailscale: ${TAILSCALE}
Kiosk: ${KIOSK}"

# ─── Only send if something changed or every hour ──────────────
LAST_REPORT_FILE="${STATE_DIR}/last-report-hash"
CURRENT_HASH="$(echo "$REPORT" | md5sum | awk '{print $1}')"
LAST_HASH=""
if [[ -f "$LAST_REPORT_FILE" ]]; then
    LAST_HASH="$(cat "$LAST_REPORT_FILE")"
fi

MINUTE="$(date +%M)"
# Send if: status changed, or it's the top of the hour (minute 00-14)
if [[ "$CURRENT_HASH" != "$LAST_HASH" ]] || [[ "$MINUTE" -lt 15 ]]; then
    "$NOTIFY" "$REPORT"
    echo "$CURRENT_HASH" > "$LAST_REPORT_FILE"
fi

# Log locally always
echo "[$(date '+%Y-%m-%d %H:%M:%S')] mode=${MODE} load=${LOAD} mem=${MEM_PERCENT}% disk=${DISK_PERCENT} internet=${INTERNET} jitsi=${HTTP_CODE} kiosk=${KIOSK}" \
    >> "${LOG_DIR}/monitor.log"
