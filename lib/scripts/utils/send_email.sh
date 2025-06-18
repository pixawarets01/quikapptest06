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
handle_error() { log "ERROR: $1"; exit 1; }
trap 'handle_error "Error occurred at line $LINENO"' ERR

SUBJECT="[QuikApp Build] $STATUS"
TO="$EMAIL_ID"

if command -v msmtp >/dev/null 2>&1; then
  log "Sending email via msmtp to $TO"
  echo -e "Subject: $SUBJECT\nTo: $TO\n\n$MESSAGE" | msmtp --host=$EMAIL_SMTP_SERVER --port=$EMAIL_SMTP_PORT --auth=on --user=$EMAIL_SMTP_USER --passwordeval="echo $EMAIL_SMTP_PASS" --from=$EMAIL_SMTP_USER $TO
elif command -v mailx >/dev/null 2>&1; then
  log "Sending email via mailx to $TO"
  echo "$MESSAGE" | mailx -s "$SUBJECT" -S smtp="smtp://$EMAIL_SMTP_SERVER:$EMAIL_SMTP_PORT" -S smtp-use-starttls -S smtp-auth=login -S smtp-auth-user="$EMAIL_SMTP_USER" -S smtp-auth-password="$EMAIL_SMTP_PASS" -S from="$EMAIL_SMTP_USER" $TO
else
  log "No supported mail client found (msmtp or mailx). Skipping email notification."
fi
log "Email notification sent successfully"
exit 0 