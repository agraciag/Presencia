#!/usr/bin/env bash
# Presencia - Full system health diagnostic
# Run manually via SSH when troubleshooting.
set -euo pipefail

CONFIG="/opt/presencia/presencia.conf"
if [[ -f "$CONFIG" ]]; then
    source "$CONFIG"
fi

STATE_DIR="${PRESENCIA_STATE_DIR:-/var/lib/presencia}"
PRESENCIA_USER="${PRESENCIA_USER:-presencia}"
JITSI_DOMAIN="${JITSI_DOMAIN:-meet.example.com}"

PRESENCIA_UID="$(id -u "$PRESENCIA_USER" 2>/dev/null || echo "")"

header() {
    echo ""
    echo "═══ $1 ═══"
}

check() {
    local label="$1"
    local result="$2"
    if [[ "$result" == "OK" ]]; then
        printf "  %-30s [OK]\n" "$label"
    else
        printf "  %-30s [FAIL] %s\n" "$label" "$result"
    fi
}

echo "╔══════════════════════════════════════════════╗"
echo "║      Presencia - Health Report               ║"
echo "║      $(date '+%Y-%m-%d %H:%M:%S %Z')              ║"
echo "╚══════════════════════════════════════════════╝"

# ─── Mode ───────────────────────────────────────────────────────
header "Current Mode"
if [[ -f "${STATE_DIR}/current-mode" ]]; then
    echo "  Mode: $(cat "${STATE_DIR}/current-mode")"
else
    echo "  Mode: unknown (state file missing)"
fi

# ─── System ─────────────────────────────────────────────────────
header "System"
echo "  Uptime: $(uptime -p)"
echo "  Load:   $(cat /proc/loadavg | awk '{print $1, $2, $3}')"
echo "  Memory: $(free -h | awk '/^Mem:/{printf "%s used / %s total (%s free)", $3, $2, $4}')"
echo "  Disk:   $(df -h / | awk 'NR==2{printf "%s used / %s total (%s avail)", $3, $2, $4}')"
echo "  Temp:   $(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null | awk '{printf "%.1f°C", $1/1000}' || echo 'N/A')"

# ─── Network ───────────────────────────────────────────────────
header "Network"
if ping -c 1 -W 3 8.8.8.8 &>/dev/null; then
    check "Internet" "OK"
else
    check "Internet" "No connectivity"
fi

if ping -c 1 -W 3 "$JITSI_DOMAIN" &>/dev/null; then
    check "Jitsi DNS" "OK"
else
    check "Jitsi DNS" "Cannot resolve ${JITSI_DOMAIN}"
fi

HTTP_CODE="$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "https://${JITSI_DOMAIN}" 2>/dev/null || echo "000")"
if [[ "$HTTP_CODE" == "200" ]]; then
    check "Jitsi HTTP" "OK"
else
    check "Jitsi HTTP" "HTTP ${HTTP_CODE}"
fi

if tailscale status &>/dev/null 2>&1; then
    check "Tailscale" "OK"
    echo "  Tailscale IP: $(tailscale ip -4 2>/dev/null || echo 'N/A')"
else
    check "Tailscale" "Not connected"
fi

# ─── Services ──────────────────────────────────────────────────
header "Services"
if [[ -n "$PRESENCIA_UID" ]]; then
    for svc in presencia-kiosk presencia-cec; do
        STATUS="$(sudo -u "$PRESENCIA_USER" XDG_RUNTIME_DIR="/run/user/${PRESENCIA_UID}" \
            systemctl --user is-active "$svc" 2>/dev/null || echo "inactive")"
        if [[ "$STATUS" == "active" ]]; then
            check "$svc" "OK"
        else
            check "$svc" "$STATUS"
        fi
    done
fi

for svc in presencia-watchdog.timer presencia-monitor.timer; do
    STATUS="$(systemctl is-active "$svc" 2>/dev/null || echo "inactive")"
    if [[ "$STATUS" == "active" ]]; then
        check "$svc" "OK"
    else
        check "$svc" "$STATUS"
    fi
done

# ─── Processes ──────────────────────────────────────────────────
header "Processes"
if pgrep -u "$PRESENCIA_USER" -f "chromium.*--kiosk" &>/dev/null; then
    CHROME_MEM="$(pgrep -u "$PRESENCIA_USER" -f "chromium" | xargs -I{} cat /proc/{}/statm 2>/dev/null | awk '{sum+=$1} END {printf "%.0f MB", sum*4096/1024/1024}')"
    check "Chromium kiosk" "OK (${CHROME_MEM})"
else
    check "Chromium kiosk" "Not running"
fi

# ─── Display ───────────────────────────────────────────────────
header "Display"
if sudo -u "$PRESENCIA_USER" DISPLAY=:0 xdpyinfo &>/dev/null 2>&1; then
    check "X11 Display" "OK"
else
    check "X11 Display" "Not available"
fi

# ─── Camera ────────────────────────────────────────────────────
header "Camera"
if ls /dev/video* &>/dev/null 2>&1; then
    for dev in /dev/video*; do
        NAME="$(v4l2-ctl --device="$dev" --info 2>/dev/null | grep "Card type" | sed 's/.*: //' || echo "unknown")"
        echo "  ${dev}: ${NAME}"
    done
else
    echo "  No video devices found!"
fi

echo ""
echo "── End of Health Report ──"
