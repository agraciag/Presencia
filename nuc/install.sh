#!/usr/bin/env bash
# Presencia - Master bootstrap installer for Intel NUC
# Run as root on a fresh Ubuntu LTS installation.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="/opt/presencia"
STATE_DIR="/var/lib/presencia"
LOG_DIR="/var/log/presencia"
PRESENCIA_USER="presencia"
CONFIG_FILE="${SCRIPT_DIR}/config/presencia.conf"

# ─── Preflight checks ──────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
    echo "Error: This script must be run as root (sudo ./install.sh)"
    exit 1
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: Config file not found at ${CONFIG_FILE}"
    echo "Copy config/presencia.conf.example to config/presencia.conf and fill in your values."
    exit 1
fi

source "$CONFIG_FILE"

echo "╔══════════════════════════════════════════════╗"
echo "║         Presencia - NUC Installer            ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

# ─── Create user ────────────────────────────────────────────────
echo "[1/8] Creating user ${PRESENCIA_USER}..."
if ! id "$PRESENCIA_USER" &>/dev/null; then
    useradd -m -s /bin/bash -G audio,video,input,plugdev "$PRESENCIA_USER"
    echo "User ${PRESENCIA_USER} created."
else
    echo "User ${PRESENCIA_USER} already exists."
fi

# ─── Create directories ────────────────────────────────────────
echo "[2/8] Creating directories..."
mkdir -p "$INSTALL_DIR" "$STATE_DIR" "$LOG_DIR"
chown "$PRESENCIA_USER":"$PRESENCIA_USER" "$STATE_DIR" "$LOG_DIR"

# Copy scripts to install dir
cp -r "${SCRIPT_DIR}"/{base,telepresence,resilience,media,monitoring} "$INSTALL_DIR/"
cp "$CONFIG_FILE" "${INSTALL_DIR}/presencia.conf"
chmod -R +x "$INSTALL_DIR"

# ─── Phase 2: Base setup ───────────────────────────────────────
echo "[3/8] Running base setup..."
bash "${SCRIPT_DIR}/base/setup-base.sh"

echo "[4/8] Setting up Tailscale..."
bash "${SCRIPT_DIR}/base/setup-tailscale.sh"

echo "[5/8] Configuring SSH..."
bash "${SCRIPT_DIR}/base/setup-ssh.sh"

echo "[6/8] Configuring firewall..."
bash "${SCRIPT_DIR}/base/setup-firewall.sh"

# ─── Phase 3: Telepresence services ────────────────────────────
echo "[7/8] Installing telepresence services..."

# Install systemd user services for the presencia user
PRESENCIA_HOME="$(eval echo ~${PRESENCIA_USER})"
SYSTEMD_USER_DIR="${PRESENCIA_HOME}/.config/systemd/user"
mkdir -p "$SYSTEMD_USER_DIR"

cp "${SCRIPT_DIR}/telepresence/presencia-kiosk.service" "$SYSTEMD_USER_DIR/"
cp "${SCRIPT_DIR}/telepresence/presencia-cec.service" "$SYSTEMD_USER_DIR/"

chown -R "$PRESENCIA_USER":"$PRESENCIA_USER" "${PRESENCIA_HOME}/.config"

# Install system-level services (watchdog, monitor)
cp "${SCRIPT_DIR}/resilience/presencia-watchdog.service" /etc/systemd/system/
cp "${SCRIPT_DIR}/resilience/presencia-watchdog.timer" /etc/systemd/system/
cp "${SCRIPT_DIR}/monitoring/presencia-monitor.service" /etc/systemd/system/
cp "${SCRIPT_DIR}/monitoring/presencia-monitor.timer" /etc/systemd/system/
cp "${SCRIPT_DIR}/media/kodi-autostart.service" /etc/systemd/system/

# Install cron for mode switching
cp "${SCRIPT_DIR}/media/presencia-mode-cron" /etc/cron.d/presencia-mode
chmod 644 /etc/cron.d/presencia-mode

# Enable lingering for the presencia user (systemd user services run without login)
loginctl enable-linger "$PRESENCIA_USER"

# ─── Enable services ───────────────────────────────────────────
echo "[8/8] Enabling services..."
systemctl daemon-reload

# Enable user services as presencia user
sudo -u "$PRESENCIA_USER" XDG_RUNTIME_DIR="/run/user/$(id -u $PRESENCIA_USER)" \
    systemctl --user enable presencia-kiosk.service
sudo -u "$PRESENCIA_USER" XDG_RUNTIME_DIR="/run/user/$(id -u $PRESENCIA_USER)" \
    systemctl --user enable presencia-cec.service

# Enable system services
systemctl enable presencia-watchdog.timer
systemctl enable presencia-monitor.timer

# Set default mode
echo "${DEFAULT_MODE:-telepresence}" > "${STATE_DIR}/current-mode"
chown "$PRESENCIA_USER":"$PRESENCIA_USER" "${STATE_DIR}/current-mode"

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║       Installation complete!                 ║"
echo "║                                              ║"
echo "║  Reboot to start telepresence:               ║"
echo "║    sudo reboot                               ║"
echo "║                                              ║"
echo "║  Or start manually:                          ║"
echo "║    sudo -u presencia systemctl --user \\      ║"
echo "║      start presencia-kiosk                   ║"
echo "╚══════════════════════════════════════════════╝"
