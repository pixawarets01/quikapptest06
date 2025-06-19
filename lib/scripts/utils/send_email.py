#!/usr/bin/env python3
import os
import sys
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

# Read arguments
if len(sys.argv) < 5:
    print("Usage: send_email.py <status> <platform> <build_id> <message>")
    sys.exit(1)

status = sys.argv[1]
platform = sys.argv[2]
build_id = sys.argv[3]
message = sys.argv[4]

# Read environment variables
EMAIL_SMTP_SERVER = os.environ.get("EMAIL_SMTP_SERVER", "smtp.gmail.com")
EMAIL_SMTP_PORT = int(os.environ.get("EMAIL_SMTP_PORT", "587"))
EMAIL_SMTP_USER = os.environ.get("EMAIL_SMTP_USER")
EMAIL_SMTP_PASS = os.environ.get("EMAIL_SMTP_PASS")
EMAIL_ID = os.environ.get("EMAIL_ID", EMAIL_SMTP_USER)
APP_NAME = os.environ.get("APP_NAME", "Unknown App")
ORG_NAME = os.environ.get("ORG_NAME", "Unknown Organization")
USER_NAME = os.environ.get("USER_NAME", "Unknown User")
VERSION_NAME = os.environ.get("VERSION_NAME", "1.0.0")
VERSION_CODE = os.environ.get("VERSION_CODE", "1")
WEB_URL = os.environ.get("WEB_URL", "https://example.com")

if not EMAIL_SMTP_USER or not EMAIL_SMTP_PASS:
    print("[send_email.py] Missing EMAIL_SMTP_USER or EMAIL_SMTP_PASS. Skipping email.")
    sys.exit(0)

# Compose email
subject = f"QuikApp Build {status.capitalize()} - {APP_NAME}"
from_addr = EMAIL_SMTP_USER
to_addr = EMAIL_ID

html = f"""
<html>
<head></head>
<body>
<h2>QuikApp Build Notification</h2>
<p><b>Status:</b> {status.capitalize()}</p>
<p><b>Platform:</b> {platform}</p>
<p><b>Build ID:</b> {build_id}</p>
<p><b>App:</b> {APP_NAME} (v{VERSION_NAME} / {VERSION_CODE})</p>
<p><b>Organization:</b> {ORG_NAME}</p>
<p><b>User:</b> {USER_NAME}</p>
<p><b>Web URL:</b> {WEB_URL}</p>
<p><b>Message:</b> {message}</p>
</body>
</html>
"""

msg = MIMEMultipart('alternative')
msg['Subject'] = subject
msg['From'] = from_addr
msg['To'] = to_addr
msg.attach(MIMEText(html, 'html'))

try:
    with smtplib.SMTP(EMAIL_SMTP_SERVER, EMAIL_SMTP_PORT) as server:
        server.starttls()
        server.login(EMAIL_SMTP_USER, EMAIL_SMTP_PASS)
        server.sendmail(from_addr, [to_addr], msg.as_string())
    print(f"[send_email.py] Email sent to {to_addr}")
except Exception as e:
    print(f"[send_email.py] Failed to send email: {e}")
    sys.exit(0) 