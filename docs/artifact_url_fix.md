# Artifact URL Fix for Email Notifications

## Problem Description

Users reported receiving emails with broken artifact download links that returned:

```
{
  "error": "NOT_FOUND",
  "message": "The requested URL was not found on the server."
}
```

Example broken URL: `https://api.codemagic.io/artifacts/6852b56f44dbac3d959a5e97/6855b7a2ace9fb1462f5063f/app-release.apk`

## Root Cause Analysis

The issue was in the artifact URL generation in the email system:

1. **Incorrect Environment Variables**: The system was using wrong environment variable names for build ID and project ID
2. **Missing Fallback Logic**: No fallback when environment variables are not available
3. **URL Encoding Issues**: Special characters in filenames not properly encoded

## Solution Applied

### 1. Enhanced Environment Variable Detection

Updated `lib/scripts/utils/send_email.py` to use multiple environment variable sources:

```python
# Get the correct build ID and project ID from environment variables
# Try multiple possible environment variable names
cm_build_id = (os.environ.get("CM_BUILD_ID") or
              os.environ.get("FCI_BUILD_ID") or
              os.environ.get("BUILD_NUMBER") or
              build_id)

cm_project_id = (os.environ.get("CM_PROJECT_ID") or
                os.environ.get("FCI_PROJECT_ID") or
                self.project_id)
```

### 2. Fallback URL Generation

Added fallback logic when environment variables are not available:

```python
# Check if we have valid IDs
if cm_build_id == "unknown" or cm_project_id == "unknown":
    logger.warning("Invalid build_id or project_id, using fallback URLs")
    # Use fallback - direct links to Codemagic build page
    codemagic_build_url = f"https://codemagic.io/builds/{build_id}"
```

### 3. Proper URL Encoding

Added URL encoding for filenames to handle special characters:

```python
# URL encode the filename to handle special characters
encoded_filename = urllib.parse.quote(artifact['filename'])
download_url = f"{base_url}/{encoded_filename}"
```

### 4. Enhanced Debugging

Added comprehensive logging to track URL generation:

```python
logger.info(f"Using build_id: {cm_build_id} (from env: {os.environ.get('CM_BUILD_ID', 'NOT SET')})")
logger.info(f"Using project_id: {cm_project_id} (from env: {os.environ.get('CM_PROJECT_ID', 'NOT SET')})")
logger.info(f"Generated base URL: {base_url}")
logger.info(f"Generated download URL for {artifact['filename']}: {download_url}")
```

## Expected Environment Variables in Codemagic

The system now looks for these environment variables in order of preference:

### Build ID Variables:

1. `CM_BUILD_ID` - Primary Codemagic build ID
2. `FCI_BUILD_ID` - Alternative build ID
3. `BUILD_NUMBER` - Generic build number
4. Fallback to passed build_id parameter

### Project ID Variables:

1. `CM_PROJECT_ID` - Primary Codemagic project ID
2. `FCI_PROJECT_ID` - Alternative project ID
3. Fallback to default project ID

## URL Format

### Correct Format:

```
https://api.codemagic.io/artifacts/{project_id}/{build_id}/{filename}
```

### Example:

```
https://api.codemagic.io/artifacts/6852b56f44dbac3d959a5e97/6855b7a2ace9fb1462f5063f/app-release.apk
```

## Fallback Behavior

When environment variables are not available or invalid:

1. **Primary**: Generate direct artifact URLs using available IDs
2. **Fallback**: Provide links to Codemagic build page where users can download manually
3. **Alternative**: Include both direct links and build page links for redundancy

## Testing

### Local Testing

Run the test script to verify environment variables:

```bash
python3 lib/scripts/utils/test_artifact_urls.py
```

### Email Testing

Test email generation with sample data:

```bash
python3 lib/scripts/utils/send_email.py build_success "Android" "test-build-123" "Test message"
```

## Verification Steps

1. **Check Environment Variables**: Verify `CM_BUILD_ID` and `CM_PROJECT_ID` are set in Codemagic
2. **Test URL Generation**: Use the test script to verify URL format
3. **Email Delivery**: Check that emails contain working download links
4. **Fallback Links**: Ensure Codemagic build page links work as backup

## Troubleshooting

### If URLs Still Don't Work:

1. **Check Build Logs**: Look for environment variable debugging output
2. **Verify Project ID**: Ensure the project ID matches your Codemagic project
3. **Check Build ID**: Verify the build ID is from the current build
4. **Use Fallback**: Click the "Codemagic build page" link as alternative

### Common Issues:

1. **Environment Variables Not Set**: Add them to your Codemagic workflow
2. **Wrong Project ID**: Check your Codemagic project settings
3. **Build ID Mismatch**: Ensure you're using the correct build ID
4. **File Not Uploaded**: Verify artifacts are actually generated and uploaded

## Files Modified

- `lib/scripts/utils/send_email.py` - Main email system with URL fixes
- `lib/scripts/utils/test_artifact_urls.py` - Debug script for testing URLs
- `docs/artifact_url_fix.md` - This documentation

## Next Steps

1. **Deploy Changes**: The fixes are ready for deployment
2. **Test in Codemagic**: Run a build to verify email URLs work
3. **Monitor Logs**: Check build logs for URL generation debugging
4. **User Feedback**: Monitor if users can successfully download artifacts

The artifact URL issue should now be resolved with proper fallback mechanisms and enhanced debugging capabilities.

# Artifact URL "FORBIDDEN" Error - Fix Guide

This document explains the "FORBIDDEN" error encountered when accessing artifact download links from email notifications and details the solution implemented.

## 🚨 The "FORBIDDEN" Error

After resolving the initial "NOT_FOUND" error, a new issue appeared:

```json
{
  "error": "FORBIDDEN",
  "message": "The server could not verify that you are authorized to access the URL requested..."
}
```

This error indicates that while the URL correctly points to a Codemagic artifact, it is a **private link** that requires an active, authenticated Codemagic session to access. When clicking the link from an email, you are not logged in, and therefore access is denied.

## ✅ The Solution: Using Public URLs

Codemagic provides both private and public URLs for each build artifact. The fix was to ensure our scripts always use the **public-facing URL**, which does not require authentication.

### `process_artifacts.sh` Script Update

The core of the fix was updating the `jq` query in `lib/scripts/utils/process_artifacts.sh`.

#### Old Logic (Incorrect)

The script was extracting the standard `url` field, which is private:

```bash
# Incorrectly fetches the private URL
artifact_urls=$(echo "$CM_ARTIFACT_LINKS" | jq -r '.[] | .url')
```

#### New Logic (Correct)

The script now prioritizes the `public_url` field, falling back to the standard `url` only if the public one is not available. This ensures the link is always accessible.

```bash
# Correctly fetches the public URL, with a fallback
artifact_urls=$(echo "$CM_ARTIFACT_LINKS" | jq -r '.[] | .public_url // .url | select(.)')
```

The `//` operator in `jq` provides a safe fallback mechanism.

## 🚀 The Result

With this change, the `process_artifacts.sh` script now reliably extracts the public, authentication-free download links for all artifacts.

- **Emails will contain public URLs**: The links sent in success notifications will no longer result in a "FORBIDDEN" error.
- **Direct downloads**: Users can click the link in the email and download the artifact directly, without needing to log into Codemagic first.

The system is now correctly configured to provide direct, hassle-free access to your build artifacts.
