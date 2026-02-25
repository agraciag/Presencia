#!/usr/bin/env bash
# Presencia - Telegram notification helper
# Sends a message to the configured Telegram chat.
#
# Usage:
#   presencia-notify.sh "Message text"
#   echo "Message" | presencia-notify.sh
set -euo pipefail

CONFIG="/opt/presencia/presencia.conf"
if [[ -f "$CONFIG" ]]; then
    source "$CONFIG"
fi

BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
CHAT_ID="${TELEGRAM_CHAT_ID:-}"

if [[ -z "$BOT_TOKEN" || -z "$CHAT_ID" ]]; then
    echo "Telegram not configured (missing BOT_TOKEN or CHAT_ID). Skipping notification."
    exit 0
fi

# Get message from argument or stdin
if [[ $# -gt 0 ]]; then
    MESSAGE="$*"
else
    MESSAGE="$(cat)"
fi

if [[ -z "$MESSAGE" ]]; then
    exit 0
fi

# Prepend hostname for context
HOSTNAME="$(hostname)"
FULL_MESSAGE="[${HOSTNAME}] ${MESSAGE}"

curl -s -X POST \
    "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -d chat_id="$CHAT_ID" \
    -d text="$FULL_MESSAGE" \
    -d parse_mode="Markdown" \
    --max-time 10 \
    > /dev/null 2>&1

exit 0
