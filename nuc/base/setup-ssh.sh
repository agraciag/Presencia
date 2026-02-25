#!/usr/bin/env bash
# Presencia - Harden SSH configuration
# Tailscale SSH is the primary access method. This hardens traditional SSH as backup.
set -euo pipefail

PRESENCIA_USER="${PRESENCIA_USER:-presencia}"

echo "── SSH Hardening ──"

# ─── Configure SSHD ────────────────────────────────────────────
cat > /etc/ssh/sshd_config.d/presencia.conf << 'SSHD'
# Presencia - Hardened SSH config
Port 2222
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
MaxAuthTries 3
ClientAliveInterval 60
ClientAliveCountMax 3
X11Forwarding no
AllowAgentForwarding no
SSHD

# ─── Create .ssh directory for presencia user ──────────────────
PRESENCIA_HOME="$(eval echo ~${PRESENCIA_USER})"
SSH_DIR="${PRESENCIA_HOME}/.ssh"
mkdir -p "$SSH_DIR"
touch "${SSH_DIR}/authorized_keys"
chmod 700 "$SSH_DIR"
chmod 600 "${SSH_DIR}/authorized_keys"
chown -R "$PRESENCIA_USER":"$PRESENCIA_USER" "$SSH_DIR"

# ─── Restart SSH ────────────────────────────────────────────────
systemctl restart sshd

echo ""
echo "SSH hardened. Key-only auth on port 2222."
echo ""
echo "IMPORTANT: Add your public key to ${SSH_DIR}/authorized_keys"
echo "  Example: ssh-copy-id -p 2222 presencia@<nuc-ip>"
echo ""
echo "Primary access should be via Tailscale SSH (port 22 over Tailscale)."
echo "This hardened SSH on port 2222 is a backup."
