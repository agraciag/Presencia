#!/usr/bin/env bash
# Generate secure passwords for Jitsi .env file
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"

if [[ ! -f "$ENV_FILE" ]]; then
    echo "Error: .env not found. Copy .env.example to .env first."
    exit 1
fi

gen_password() {
    openssl rand -hex 16
}

echo "Generating passwords..."

declare -a KEYS=(
    JICOFO_AUTH_PASSWORD
    JVB_AUTH_PASSWORD
    JIGASI_XMPP_PASSWORD
    JIBRI_RECORDER_PASSWORD
    JIBRI_XMPP_PASSWORD
    JICOFO_COMPONENT_SECRET
)

for key in "${KEYS[@]}"; do
    password="$(gen_password)"
    # Replace empty value or existing value for the key
    sed -i "s|^${key}=.*|${key}=${password}|" "$ENV_FILE"
    echo "  ${key} ✓"
done

echo ""
echo "Passwords written to ${ENV_FILE}"
echo "Remember to also set JITSI_DOMAIN, LETSENCRYPT_EMAIL, and JVB_ADVERTISE_IPS."
