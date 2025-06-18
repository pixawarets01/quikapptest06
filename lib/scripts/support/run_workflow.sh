#!/bin/bash
# Universal QuikApp workflow runner for local testing
# Usage: bash lib/scripts/support/run_workflow.sh <workflow>
# <workflow>: android-free | android-paid | android-publish | ios-only | combined

set -euo pipefail
trap 'echo "[ERROR] Script failed at line $LINENO"; exit 1' ERR

if [ $# -ne 1 ]; then
  echo "Usage: $0 <workflow>"
  echo "  <workflow>: android-free | android-paid | android-publish | ios-only | combined"
  exit 1
fi

WORKFLOW="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR/../../.."

cd "$PROJECT_ROOT"

# Source environment variables
if [ -f "env.sh" ]; then
  source env.sh
else
  echo "[WARN] env.sh not found. Using current environment."
fi

export WORKFLOW_ID="$WORKFLOW"

case "$WORKFLOW" in
  android-free|android-paid|android-publish)
    bash lib/scripts/android/main.sh
    ;;
  ios-only)
    bash lib/scripts/ios/main.sh
    ;;
  combined)
    bash lib/scripts/combined/main.sh
    ;;
  *)
    echo "[ERROR] Unknown workflow: $WORKFLOW"
    exit 1
    ;;
esac

# Output summary
echo "\n[INFO] Build artifacts (if successful):"
if [[ "$WORKFLOW" == android* || "$WORKFLOW" == combined ]]; then
  echo "  APKs:    output/android/*.apk"
  echo "  AABs:    output/android/*.aab (if applicable)"
fi
if [[ "$WORKFLOW" == ios-only || "$WORKFLOW" == combined ]]; then
  echo "  IPAs:    output/ios/*.ipa"
fi 