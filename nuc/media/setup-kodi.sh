#!/usr/bin/env bash
# Presencia - Install and configure Kodi
set -euo pipefail

PRESENCIA_USER="${PRESENCIA_USER:-presencia}"

echo "── Kodi Setup ──"

# ─── Install Kodi ──────────────────────────────────────────────
echo "Installing Kodi..."
apt-get install -y -qq kodi 2>/dev/null

echo "Kodi installed."
echo ""
echo "Kodi will be managed by systemd (kodi-autostart.service)."
echo "To switch to media mode: presencia-mode-switch.sh media"
