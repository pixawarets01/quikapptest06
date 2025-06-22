#!/bin/bash

echo "🔍 Keystore Fingerprint Checker"
echo "==============================="

# Keystore details from your configuration
KEYSTORE_URL="https://raw.githubusercontent.com/prasanna91/QuikApp/main/keystore.jks"
KEYSTORE_PASSWORD="opeN@1234"
KEY_ALIAS="my_key_alias"

echo ""
echo "📥 Downloading keystore from: $KEYSTORE_URL"
curl -L "$KEYSTORE_URL" -o temp_keystore.jks

if [ -f "temp_keystore.jks" ]; then
    echo "✅ Keystore downloaded successfully"
    
    echo ""
    echo "🔍 Checking keystore fingerprint..."
    echo ""
    
    # Get the fingerprint
    keytool -list -v -alias "$KEY_ALIAS" -keystore temp_keystore.jks -storepass "$KEYSTORE_PASSWORD" | grep "SHA1:"
    
    echo ""
    echo "📋 Expected fingerprint (from Google Play Console):"
    echo "SHA1: 15:43:4B:69:09:E9:93:62:85:C1:EC:BE:F3:17:CC:BD:EC:F7:EC:5E"
    
    echo ""
    echo "📋 Actual fingerprint (from uploaded AAB):"
    echo "SHA1: 66:F9:1A:4D:57:A2:ED:F8:05:7E:36:93:5E:11:F9:F6:13:A8:2B:92"
    
    echo ""
    echo "🔍 Full keystore details:"
    keytool -list -v -keystore temp_keystore.jks -storepass "$KEYSTORE_PASSWORD"
    
    # Cleanup
    rm temp_keystore.jks
else
    echo "❌ Failed to download keystore"
fi

echo ""
echo "🎯 Next Steps:"
echo "1. If fingerprints match expected: Your keystore is correct"
echo "2. If fingerprints don't match: You need the original keystore"
echo "3. Check if you have multiple keystores for different environments" 