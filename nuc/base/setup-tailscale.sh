#!/usr/bin/env bash
# Presencia - Install and configure Tailscale for remote access
set -euo pipefail

echo "── Tailscale Setup ──"

# ─── Install Tailscale ──────────────────────────────────────────
if ! command -v tailscale &>/dev/null; then
    echo "Installing Tailscale..."
    curl -fsSL https://tailscale.com/install.sh | sh
else
    echo "Tailscale already installed."
fi

# ─── Start Tailscale with SSH enabled ──────────────────────────
echo ""
echo "Starting Tailscale..."
echo "You will need to authenticate via the URL shown below."
echo ""

tailscale up --ssh

echo ""
echo "Tailscale status:"
tailscale status
echo ""
echo "Tailscale IP: $(tailscale ip -4)"
echo ""
echo "Tailscale SSH is enabled. You can now SSH to this machine via:"
echo "  ssh presencia@$(tailscale ip -4)"
echo ""
echo "Tailscale setup complete."
