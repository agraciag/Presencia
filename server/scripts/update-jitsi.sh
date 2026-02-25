#!/usr/bin/env bash
# Update Jitsi Docker images with backup and rollback support
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_DIR="$(dirname "$SCRIPT_DIR")"

cd "$SERVER_DIR"

echo "=== Jitsi Update ==="
echo ""

# Step 1: Backup current config
echo "[1/4] Creating backup..."
"${SCRIPT_DIR}/backup-jitsi.sh"
echo ""

# Step 2: Pull latest images
echo "[2/4] Pulling latest images..."
docker compose pull
echo ""

# Step 3: Recreate containers
echo "[3/4] Recreating containers..."
docker compose up -d --remove-orphans
echo ""

# Step 4: Verify
echo "[4/4] Verifying..."
sleep 10

if docker compose ps --format '{{.State}}' | grep -qv "running"; then
    echo "WARNING: Some containers are not running!"
    docker compose ps
    echo ""
    echo "Check logs with: docker compose logs"
    exit 1
fi

echo "All containers running."
docker compose ps
echo ""
echo "Update complete. Test a call to verify everything works."
