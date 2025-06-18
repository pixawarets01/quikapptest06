#!/bin/bash

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../../.." && pwd )"

# Source common variables
source "$SCRIPT_DIR/variables.sh"

# Function to send email notification using SMTP
send_notification() {
  local status=$1
  local message=$2
  local logs_url=$3
  
  # Get build info from environment variables
  local build_number=${BUILD_NUMBER:-"unknown"}
  local build_id=${BUILD_ID:-"unknown"}
  local project_name=${PROJECT_NAME:-"Flutter Project"}

  
  # Format email subject
  local subject="[${status}] ${project_name} Build #${build_number}"
  
  # Lowercase status for CSS class
  local status_class=$(echo "$status" | tr '[:upper:]' '[:lower:]')
  
  # Format email body in HTML
  local body="
<!DOCTYPE html>
<html>
<head>
  <style>
    body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
    .header { background-color: #f8f9fa; padding: 20px; border-radius: 5px; }
    .content { padding: 20px; }
    .footer { text-align: center; padding: 20px; font-size: 12px; color: #666; }
    .button { display: inline-block; padding: 10px 20px; background-color: #007bff; color: white; text-decoration: none; border-radius: 5px; }
    .status-success { color: #28a745; }
    .status-failed { color: #dc3545; }
  </style>
</head>
<body>
  <div class='container'>
    <div class='header'>
      <h2>${project_name} Build Notification</h2>
      <p>Build #${build_number} (${build_id})</p>
    </div>
    <div class='content'>
      <h3 class='status-${status_class}'>Status: ${status}</h3>
      <p>${message}</p>
      <p><a href='${logs_url}' class='button'>View Build Logs</a></p>
    </div>
    <div class='footer'>
      <p>This is an automated message from Codemagic CI/CD</p>
    </div>
  </div>
</body>
</html>
"
  
  # Create temporary file for email content
  local email_file=$(mktemp)
  echo "$body" > "$email_file"
  
  # Send email using curl with SMTP
  if command -v curl &> /dev/null; then
    echo "Sending email notification using SMTP..."
    curl --url "smtp://${SMTP_SERVER}:${SMTP_PORT}" \
         --mail-from "${SMTP_USER}" \
         --mail-rcpt "${NOTIFICATION_EMAIL:-}" \
         --ssl-reqd \
         --user "${SMTP_USER}:${SMTP_PASS}" \
         --upload-file "$email_file" \
         --verbose || echo "[WARN] Failed to send email notification"
  else
    echo "[WARN] curl command not available. Skipping email notification."
    echo "Would have sent:"
    echo "Subject: ${subject}"
    echo "Body: ${body}"
  fi
  
  # Clean up temporary file
  rm -f "$email_file"
}

# Function to send build start notification
send_build_start_notification() {
  local workflow_name=$1
  send_notification "STARTED" "Build started for ${workflow_name} workflow" "${BUILD_URL:-}"
}

# Function to send build success notification
send_build_success_notification() {
  local workflow_name=$1
  local artifact_url=$2
  send_notification "SUCCESS" "Build completed successfully for ${workflow_name} workflow. Artifact: ${artifact_url}" "${BUILD_URL:-}"
}

# Function to send build failure notification
send_build_failure_notification() {
  local workflow_name=$1
  local error_message=$2
  send_notification "FAILED" "Build failed for ${workflow_name} workflow. Error: ${error_message}" "${BUILD_URL:-}"
} 