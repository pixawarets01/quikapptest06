#!/bin/bash
set -euo pipefail

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] [ARTIFACTS] $1"; }

# process_artifacts: Processes Codemagic artifact links to generate download URLs
#
# This function reads the CM_ARTIFACT_LINKS environment variable, which contains
# a JSON array of artifact objects. It uses `jq` to parse this JSON and extract
# the public-facing download URL for each artifact.
#
# The URLs are then formatted into a single string, separated by newlines,
# which can be passed to the email notification script.
#
# If CM_ARTIFACT_LINKS is not set or is empty, it logs a warning and returns
# a "Not available" message.
#
# Returns:
#   A string containing all artifact download URLs, separated by newlines.
process_artifacts() {
    log "Processing artifact links..."

    if [[ -z "${CM_ARTIFACT_LINKS:-}" ]]; then
        log "⚠️ CM_ARTIFACT_LINKS variable is not set. No artifact URLs available."
        echo "Artifacts not available."
        return
    fi

    log "Raw artifact JSON: $CM_ARTIFACT_LINKS"

    # Use jq to parse the JSON and extract the 'url' for each artifact
    # The 'select(.url)' ensures we only process entries that have a URL
    # The '@text' ensures the output is a plain string
    local artifact_urls
    artifact_urls=$(echo "$CM_ARTIFACT_LINKS" | jq -r '.[] | select(.url) | .url | @text')

    if [[ -z "$artifact_urls" ]]; then
        log "⚠️ Could not parse any URLs from CM_ARTIFACT_LINKS."
        echo "Artifacts not available."
        return
    fi

    log "✅ Successfully processed artifact URLs:"
    # Log each URL for debugging
    while IFS= read -r url; do
        log "   - $url"
    done <<< "$artifact_urls"

    # Return the newline-separated list of URLs
    echo "$artifact_urls"
} 