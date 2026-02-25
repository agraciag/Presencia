#!/usr/bin/env bash
# Presencia - Firewall configuration
# Deny all incoming except Tailscale interface.
set -euo pipefail

echo "── Firewall Setup ──"

# ─── Install and configure UFW ──────────────────────────────────
apt-get install -y -qq ufw 2>/dev/null

# Reset to defaults
ufw --force reset

# Default policies
ufw default deny incoming
ufw default allow outgoing

# Allow all traffic on Tailscale interface
ufw allow in on tailscale0

# Allow SSH on port 2222 (backup, only from local network)
ufw allow in on tailscale0 to any port 2222 proto tcp

# Enable firewall
ufw --force enable

echo ""
echo "Firewall configured:"
ufw status verbose
echo ""
echo "Only Tailscale traffic is allowed in. All outgoing traffic is allowed."
