#!/bin/bash
set -euo pipefail

STATUS=$1
MESSAGE=$2

EMAIL_SMTP_SERVER=${EMAIL_SMTP_SERVER:-}
EMAIL_SMTP_PORT=${EMAIL_SMTP_PORT:-}
EMAIL_SMTP_USER=${EMAIL_SMTP_USER:-}
EMAIL_SMTP_PASS=${EMAIL_SMTP_PASS:-}
EMAIL_ID=${EMAIL_ID:-}

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"; }

SUBJECT="[QuikApp Build] $STATUS"
TO="$EMAIL_ID"

if command -v msmtp >/dev/null 2>&1; then
  log "Sending email via msmtp to $TO"
  echo -e "Subject: $SUBJECT\nTo: $TO\n\n$MESSAGE" | msmtp --host=$EMAIL_SMTP_SERVER --port=$EMAIL_SMTP_PORT --auth=on --user=$EMAIL_SMTP_USER --passwordeval="echo $EMAIL_SMTP_PASS" --from=$EMAIL_SMTP_USER $TO
  log "Email notification sent successfully"
else
  log "msmtp not available. Email notification skipped. Status: $STATUS - $MESSAGE"
fi
exit 0 