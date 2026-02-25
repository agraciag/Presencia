#!/usr/bin/env bash
# Backup Jitsi configuration and data
set -euo pipefail

CONFIG_DIR="${CONFIG:-$HOME/.jitsi-meet-cfg}"
BACKUP_DIR="${1:-$HOME/jitsi-backups}"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_FILE="${BACKUP_DIR}/jitsi-backup-${TIMESTAMP}.tar.gz"

mkdir -p "$BACKUP_DIR"

echo "Backing up Jitsi config from ${CONFIG_DIR}..."
tar -czf "$BACKUP_FILE" -C "$(dirname "$CONFIG_DIR")" "$(basename "$CONFIG_DIR")"

echo "Backup saved to ${BACKUP_FILE}"
echo "Size: $(du -h "$BACKUP_FILE" | cut -f1)"

# Keep only last 10 backups
cd "$BACKUP_DIR"
ls -t jitsi-backup-*.tar.gz 2>/dev/null | tail -n +11 | xargs -r rm -f
echo "Cleanup done (keeping last 10 backups)."
