#!/bin/bash
set -euo pipefail

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"; }
handle_error() {
  log "ERROR: $1"
  ./lib/scripts/utils/send_email.sh "failure" "Combined build failed: $1"
  exit 1
}
trap 'handle_error "Error occurred at line $LINENO"' ERR

chmod +x ./lib/scripts/android/*.sh || true
chmod +x ./lib/scripts/ios/*.sh || true
chmod +x ./lib/scripts/utils/*.sh || true

log "Starting combined Android & iOS build workflow"

log "Running Android build..."
./lib/scripts/android/main.sh || handle_error "Android build failed"

log "Running iOS build..."
./lib/scripts/ios/main.sh || handle_error "iOS build failed"

./lib/scripts/utils/send_email.sh "success" "Combined Android & iOS build completed successfully"
log "Combined build completed successfully"
exit 0 