import smtplib
import ssl
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from email.mime.base import MIMEBase
from email import encoders
import sys
import os

def send_email(smtp_server, smtp_port, sender_email, sender_password, receiver_email, subject, body_file, log_file_path=None, apk_path=None, aab_path=None):
    """Sends an email with HTML content and optional attachments."""
    
    with open(body_file, 'r') as f:
        html_body = f.read()

    message = MIMEMultipart("mixed")  # Change to "mixed" for attachments
    message["Subject"] = subject
    message["From"] = sender_email
    message["To"] = receiver_email

    # Attach HTML part
    html_part = MIMEText(html_body, "html")
    message.attach(html_part)

    # Attach log file if provided
    if log_file_path and os.path.exists(log_file_path):
        try:
            with open(log_file_path, "rb") as attachment:
                part = MIMEBase("application", "octet-stream")
                part.set_payload(attachment.read())
            encoders.encode_base64(part)
            part.add_header(
                "Content-Disposition",
                f"attachment; filename= {os.path.basename(log_file_path)}",
            )
            message.attach(part)
        except Exception as e:
            print(f"Warning: Could not attach log file {log_file_path}: {e}")

    # Attach APK file if provided
    if apk_path and os.path.exists(apk_path):
        try:
            with open(apk_path, "rb") as attachment:
                part = MIMEBase("application", "vnd.android.package-archive")
                part.set_payload(attachment.read())
            encoders.encode_base64(part)
            part.add_header(
                "Content-Disposition",
                f"attachment; filename= {os.path.basename(apk_path)}",
            )
            message.attach(part)
        except Exception as e:
            print(f"Warning: Could not attach APK file {apk_path}: {e}")

    # Attach AAB file if provided
    if aab_path and os.path.exists(aab_path):
        try:
            with open(aab_path, "rb") as attachment:
                part = MIMEBase("application", "octet-stream")
                part.set_payload(attachment.read())
            encoders.encode_base64(part)
            part.add_header(
                "Content-Disposition",
                f"attachment; filename= {os.path.basename(aab_path)}",
            )
            message.attach(part)
        except Exception as e:
            print(f"Warning: Could not attach AAB file {aab_path}: {e}")

    context = ssl.create_default_context()
    try:
        with smtplib.SMTP(smtp_server, int(smtp_port)) as server:
            server.starttls(context=context)
            server.login(sender_email, sender_password)
            server.sendmail(sender_email, receiver_email, message.as_string())
        print("Email sent successfully!")
    except ssl.SSLError as ssl_err:
        print(f"SSL certificate verification failed: {ssl_err}. Retrying without certificate verification...")
        try:
            # Retry with unverified context
            context = ssl.create_unverified_context()
            with smtplib.SMTP(smtp_server, int(smtp_port)) as server:
                server.starttls(context=context)
                server.login(sender_email, sender_password)
                server.sendmail(sender_email, receiver_email, message.as_string())
            print("Email sent successfully (without certificate verification)!")
        except Exception as retry_e:
            print(f"Error sending email even after retrying without certificate verification: {retry_e}")
            sys.exit(1)
    except Exception as e:
        print(f"Error sending email: {e}")
        sys.exit(1)

if __name__ == "__main__":
    # Expected arguments: 
    # 1: smtp_server
    # 2: smtp_port
    # 3: sender_email
    # 4: sender_password
    # 5: sender_email (again, from bash, not used directly here)
    # 6: recipient_email
    # 7: subject
    # 8: body_file
    # 9: log_file_path (optional)
    # 10: apk_path (optional)
    # 11: aab_path (optional)
    
    # The script can be called with 8 (for started), 10 (for success with apk/aab), 
    # or 9 arguments (for failure with log)
    if len(sys.argv) < 9 or len(sys.argv) > 12: # Adjusted range to allow for optional attachments
        print("Usage: python send_email_python.py <smtp_server> <smtp_port> <sender_email> <sender_password> <sender_email_again> <recipient_email> <subject> <body_file> [log_file_path] [apk_path] [aab_path]")
        sys.exit(1)

    smtp_server = sys.argv[1]
    smtp_port = sys.argv[2]
    sender_email = sys.argv[3]
    sender_password = sys.argv[4]
    receiver_email = sys.argv[6] 
    subject = sys.argv[7]
    body_file = sys.argv[8]
    
    log_file_path = sys.argv[9] if len(sys.argv) > 9 else None
    apk_path = sys.argv[10] if len(sys.argv) > 10 else None
    aab_path = sys.argv[11] if len(sys.argv) > 11 else None

    send_email(smtp_server, smtp_port, sender_email, sender_password, receiver_email, subject, body_file, log_file_path, apk_path, aab_path) 