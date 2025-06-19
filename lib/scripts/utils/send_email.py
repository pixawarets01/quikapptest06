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

# Determine status colors and icons
status_config = {
    "build_started": {"color": "#667eea", "icon": "🧱", "title": "Build Started", "icon2": "🏗️"},
    "build_success": {"color": "#11998e", "icon": "🏆", "title": "Build Successful", "icon2": "👑"},
    "build_failed": {"color": "#ff6b6b", "icon": "🚫", "title": "Build Failed", "icon2": "🛑"}
}

config = status_config.get(status, {"color": "#6c757d", "icon": "ℹ️", "title": "Build Update"})

# Compose email with QuikApp styling
subject = f"{config['icon2']} QuikApp {config['title']} - {APP_NAME}"
from_addr = EMAIL_SMTP_USER
to_addr = EMAIL_ID

html = f"""
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>QuikApp {config['title']}</title>
    <style>
        * {{
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }}
        
        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            line-height: 1.6;
            color: #333;
            background: linear-gradient(135deg, #f5f7fa 0%, #c3cfe2 100%);
            min-height: 100vh;
            padding: 20px;
        }}
        

.container {{
    width: 90%;
    max-width: 600px;
    margin: 0 auto;
    background: white;
    border-radius: 20px;
    box-shadow: 0 20px 40px rgba(0,0,0,0.1);
    overflow: hidden;
}}
@media (min-width: 992px) {{
    .container {{
        max-width: none;
        width: auto;
    }}
}}
        
        .header {{
            background: linear-gradient(135deg, {config['color']} 0%, {config['color']}dd 100%);
            color: white;
            padding: 40px 30px;
            text-align: center;
            position: relative;
        }}
        
        .header::before {{
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background: url('data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><defs><pattern id="grain" width="100" height="100" patternUnits="userSpaceOnUse"><circle cx="25" cy="25" r="1" fill="white" opacity="0.1"/><circle cx="75" cy="75" r="1" fill="white" opacity="0.1"/><circle cx="50" cy="10" r="0.5" fill="white" opacity="0.1"/></pattern></defs><rect width="100" height="100" fill="url(%23grain)"/></svg>');
            opacity: 0.3;
        }}
        
        .header-content {{
            position: relative;
            z-index: 1;
        }}
        
        .status-icon {{
            font-size: 48px;
            margin-bottom: 15px;
            display: block;
        }}
        
        .status-title {{
            font-size: 28px;
            font-weight: 700;
            margin-bottom: 10px;
            letter-spacing: -0.5px;
        }}
        
        .status-subtitle {{
            font-size: 16px;
            opacity: 0.9;
            font-weight: 400;
        }}
        
        .content {{
            padding: 40px 30px;
        }}
        
        .info-grid {{
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 20px;
            margin-bottom: 30px;
        }}
        
        .info-card {{
            background: #f8f9fa;
            padding: 20px;
            border-radius: 12px;
            border-left: 4px solid {config['color']};
        }}
        
        .info-label {{
            font-size: 12px;
            text-transform: uppercase;
            letter-spacing: 1px;
            color: #6c757d;
            font-weight: 600;
            margin-bottom: 5px;
        }}
        
        .info-value {{
            font-size: 16px;
            font-weight: 600;
            color: #2c3e50;
        }}
        
        .app-details {{
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            border-radius: 16px;
            margin-bottom: 30px;
            text-align: center;
        }}
        
        .app-name {{
            font-size: 24px;
            font-weight: 700;
            margin-bottom: 10px;
        }}
        
        .app-version {{
            font-size: 14px;
            opacity: 0.9;
        }}
        
        .message-section {{
            background: #fff;
            border: 2px solid #e9ecef;
            border-radius: 12px;
            padding: 25px;
            margin-bottom: 30px;
        }}
        
        .message-title {{
            font-size: 18px;
            font-weight: 600;
            color: #2c3e50;
            margin-bottom: 15px;
            display: flex;
            align-items: center;
            gap: 10px;
        }}
        
        .message-content {{
            color: #6c757d;
            line-height: 1.7;
        }}
        
        .footer {{
            background: #2c3e50;
            color: white;
            padding: 30px;
            text-align: center;
        }}
        
        .footer-links {{
            display: flex;
            justify-content: center;
            gap: 20px;
            margin-bottom: 20px;
        }}
        
        .footer-link {{
            color: #667eea;
            text-decoration: none;
            font-weight: 500;
            transition: color 0.3s ease;
        }}
        
        .footer-link:hover {{
            color: #764ba2;
        }}
        
        .footer-text {{
            font-size: 14px;
            opacity: 0.8;
        }}
        
        .quikapp-logo {{
            font-size: 20px;
            font-weight: 700;
            color: #667eea;
            margin-bottom: 10px;
        }}
        
        @media (max-width: 600px) {{
            .info-grid {{
                grid-template-columns: 1fr;
            }}
            
            .footer-links {{
                flex-direction: column;
                gap: 10px;
            }}
        }}
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="header-content">
                <span class="status-icon">{config['icon']}</span>
                <h1 class="status-title">{config['title']}</h1>
                <p class="status-subtitle">Your QuikApp build process update</p>
            </div>
        </div>
        
        <div class="content">
            <div class="app-details">
                <div class="app-name">{APP_NAME}</div>
                <div class="app-version">Version {VERSION_NAME} ({VERSION_CODE}) • {ORG_NAME}</div>
            </div>
            
            <div class="info-grid">
                <div class="info-card">
                    <div class="info-label">Platform</div>
                    <div class="info-value">{platform}</div>
                </div>
                <div class="info-card">
                    <div class="info-label">Build ID</div>
                    <div class="info-value">{build_id}</div>
                </div>
                <div class="info-card">
                    <div class="info-label">User</div>
                    <div class="info-value">{USER_NAME}</div>
                </div>
                <div class="info-card">
                    <div class="info-label">Website</div>
                    <div class="info-value">{WEB_URL}</div>
                </div>
            </div>
            
            <div class="message-section">
                <div class="message-title">
                    <span>📋</span>
                    Build Details
                </div>
                <div class="message-content">
                    {message}
                </div>
            </div>
        </div>
        
        <div class="footer">
            <div class="quikapp-logo">QuikApp</div>
            <div class="footer-links">
                <a href="https://quikapp.co" class="footer-link">Website</a>
                <a href="https://app.quikapp.co" class="footer-link">Portal</a>
                <a href="https://docs.quikapp.co" class="footer-link">Documentation</a>
                <a href="mailto:support@quikapp.co" class="footer-link">Support</a>
            </div>
            <div class="footer-text">
                © 2025 QuikApp. All rights reserved. | Automated build notification
            </div>
        </div>
    </div>
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