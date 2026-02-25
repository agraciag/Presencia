#!/usr/bin/env bash
# Presencia - Remote power cycle via Tasmota smart plug
# Run this from SPAIN (not from the NUC) when the NUC is completely unresponsive.
# Requires Tailscale subnet routing to reach Tasmota on Mexico's local network.
#
# Usage:
#   tasmota-power-cycle.sh                    # Uses IP from presencia.conf
#   tasmota-power-cycle.sh 192.168.1.100     # Specify IP directly
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${SCRIPT_DIR}/../config/presencia.conf"
if [[ -f "$CONFIG" ]]; then
    source "$CONFIG"
fi

TASMOTA_IP="${1:-${TASMOTA_IP:-}}"

if [[ -z "$TASMOTA_IP" ]]; then
    echo "Error: Tasmota IP not configured."
    echo "Usage: $0 <tasmota-ip>"
    echo "Or set TASMOTA_IP in presencia.conf"
    exit 1
fi

TASMOTA_URL="http://${TASMOTA_IP}/cm"

echo "╔══════════════════════════════════════════════╗"
echo "║  POWER CYCLE - Last resort recovery          ║"
echo "║  Target: ${TASMOTA_IP}                       "
echo "╚══════════════════════════════════════════════╝"
echo ""

# Verify Tasmota is reachable
echo "Checking Tasmota connectivity..."
if ! curl -s --max-time 5 "${TASMOTA_URL}?cmnd=Status" &>/dev/null; then
    echo "Error: Cannot reach Tasmota at ${TASMOTA_IP}"
    echo "Ensure Tailscale subnet routing is configured."
    exit 1
fi

echo "Tasmota reachable. Current status:"
curl -s "${TASMOTA_URL}?cmnd=Power" | jq . 2>/dev/null || curl -s "${TASMOTA_URL}?cmnd=Power"
echo ""

read -r -p "Power cycle the NUC? This will cut power for 10 seconds. [y/N] " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo "Turning OFF..."
curl -s "${TASMOTA_URL}?cmnd=Power%20Off" > /dev/null

echo "Waiting 10 seconds..."
sleep 10

echo "Turning ON..."
curl -s "${TASMOTA_URL}?cmnd=Power%20On" > /dev/null

echo ""
echo "Power cycle complete. NUC should boot in ~60 seconds."
echo "Monitor with: ssh presencia@<tailscale-ip> 'systemctl --user status presencia-kiosk'"
