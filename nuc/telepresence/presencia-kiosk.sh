#!/usr/bin/env bash
# Presencia - Chromium Kiosk Launcher
# Opens Chromium in kiosk mode, auto-joins Jitsi room with camera/mic enabled.
# Designed to run as a systemd user service with Restart=always.
set -euo pipefail

CONFIG="/opt/presencia/presencia.conf"
if [[ -f "$CONFIG" ]]; then
    source "$CONFIG"
fi

JITSI_URL="${JITSI_URL:-https://meet.example.com/familia}"
DISPLAY_NAME="${JITSI_DISPLAY_NAME:-Casa México}"
LOG_DIR="${PRESENCIA_LOG_DIR:-/var/log/presencia}"

# Build the full Jitsi URL with config parameters
# These URL params configure Jitsi without needing server-side changes
JITSI_FULL_URL="${JITSI_URL}#config.prejoinConfig.enabled=false&userInfo.displayName=${DISPLAY_NAME// /%20}"

# ─── Clean up Chromium crash flags ──────────────────────────────
# Prevents "Chromium didn't shut down correctly" restore dialog
CHROMIUM_DIR="${HOME}/.config/chromium"
if [[ -d "$CHROMIUM_DIR" ]]; then
    find "$CHROMIUM_DIR" -name "Preferences" -exec \
        sed -i 's/"exited_cleanly":false/"exited_cleanly":true/g; s/"exit_type":"Crashed"/"exit_type":"Normal"/g' {} + 2>/dev/null || true
fi

# ─── Wait for display ──────────────────────────────────────────
for i in $(seq 1 30); do
    if xdpyinfo &>/dev/null 2>&1; then
        break
    fi
    echo "Waiting for display... (${i}/30)"
    sleep 1
done

if ! xdpyinfo &>/dev/null 2>&1; then
    echo "Error: No display available after 30 seconds."
    exit 1
fi

# ─── Kill any existing Chromium instances ───────────────────────
pkill -f "chromium.*--kiosk" 2>/dev/null || true
sleep 1

# ─── Launch Chromium ────────────────────────────────────────────
echo "Launching Chromium kiosk → ${JITSI_URL}"

exec chromium-browser \
    --kiosk \
    --no-first-run \
    --disable-infobars \
    --disable-session-crashed-bubble \
    --disable-features=TranslateUI \
    --disable-extensions \
    --disable-component-update \
    --disable-background-networking \
    --disable-sync \
    --disable-default-apps \
    --noerrdialogs \
    --no-default-browser-check \
    --autoplay-policy=no-user-gesture-required \
    --use-fake-ui-for-media-stream \
    --enable-features=WebRTCPipeWireCapturer \
    --window-size=1920,1080 \
    --window-position=0,0 \
    --start-fullscreen \
    --disable-gpu-sandbox \
    --enable-gpu-rasterization \
    --user-data-dir="${CHROMIUM_DIR:-${HOME}/.config/chromium}" \
    "$JITSI_FULL_URL" \
    2>>"${LOG_DIR}/kiosk-stderr.log"
