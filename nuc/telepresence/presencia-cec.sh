#!/usr/bin/env bash
# Presencia - HDMI-CEC TV control
# Controls TV power via HDMI-CEC using cec-client.
#
# Usage:
#   presencia-cec.sh on      # Turn TV on + switch to NUC input
#   presencia-cec.sh off     # Turn TV off (standby)
#   presencia-cec.sh status  # Check TV power status
set -euo pipefail

CONFIG="/opt/presencia/presencia.conf"
if [[ -f "$CONFIG" ]]; then
    source "$CONFIG"
fi

CEC_DEVICE="${CEC_DEVICE:-}"
CEC_ARGS=""
if [[ -n "$CEC_DEVICE" ]]; then
    CEC_ARGS="-p $CEC_DEVICE"
fi

ACTION="${1:-status}"

cec_send() {
    echo "$1" | cec-client $CEC_ARGS -s -d 1
}

case "$ACTION" in
    on)
        echo "Turning TV on and switching input..."
        # Turn on TV (address 0 = TV)
        cec_send "on 0"
        sleep 2
        # Set NUC as active source
        cec_send "as"
        echo "TV on."
        ;;
    off)
        echo "Turning TV off (standby)..."
        cec_send "standby 0"
        echo "TV standby."
        ;;
    status)
        echo "Querying TV power status..."
        RESULT="$(echo "pow 0" | cec-client $CEC_ARGS -s -d 1 2>/dev/null | grep -i "power status:" || echo "unknown")"
        echo "TV $RESULT"
        ;;
    *)
        echo "Usage: $0 {on|off|status}"
        exit 1
        ;;
esac
