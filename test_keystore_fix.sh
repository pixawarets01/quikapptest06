#!/bin/bash

# Test script to verify keystore path fix
set -e

echo "🔧 Testing Keystore Path Fix"
echo "============================"

# Set up test environment
export WORKFLOW_ID="android-publish"
export PKG_NAME="com.garbcode.garbcodeapp"
export KEY_STORE_URL="https://raw.githubusercontent.com/prasanna91/QuikApp/main/keystore.jks"
export CM_KEYSTORE_PASSWORD="opeN@1234"
export CM_KEY_ALIAS="my_key_alias"
export CM_KEY_PASSWORD="opeN@1234"

echo "📋 Test Configuration:"
echo "Workflow: $WORKFLOW_ID"
echo "Package: $PKG_NAME"
echo "Keystore URL: $KEY_STORE_URL"
echo ""

# Create test directories
mkdir -p android/app/src

echo "🧪 Step 1: Downloading keystore..."
curl -L "$KEY_STORE_URL" -o android/app/src/keystore.jks

echo "🧪 Step 2: Creating keystore.properties..."
cat > android/app/src/keystore.properties <<EOF
storeFile=keystore.jks
storePassword=$CM_KEYSTORE_PASSWORD
keyAlias=$CM_KEY_ALIAS
keyPassword=$CM_KEY_PASSWORD
EOF

echo "🧪 Step 3: Generating build.gradle.kts..."
# Run the main script to generate build.gradle.kts
bash lib/scripts/android/main.sh

echo "🧪 Step 4: Verifying keystore configuration..."
echo ""

# Check if keystore file exists
if [ -f "android/app/src/keystore.jks" ]; then
    echo "✅ Keystore file: android/app/src/keystore.jks"
    echo "   Size: $(ls -lh android/app/src/keystore.jks | awk '{print $5}')"
else
    echo "❌ Keystore file not found"
    exit 1
fi

# Check if keystore properties exists
if [ -f "android/app/src/keystore.properties" ]; then
    echo "✅ Keystore properties: android/app/src/keystore.properties"
    echo "   Content:"
    cat android/app/src/keystore.properties | sed 's/^/   /'
else
    echo "❌ Keystore properties not found"
    exit 1
fi

# Check build.gradle.kts configuration
echo ""
echo "🧪 Step 5: Verifying build.gradle.kts..."
if grep -q "storeFile = file(\"src/\" + keystoreProperties\[\"storeFile\"\] as String)" android/app/build.gradle.kts; then
    echo "✅ Correct storeFile path in build.gradle.kts"
else
    echo "❌ Incorrect storeFile path in build.gradle.kts"
    echo "Expected: storeFile = file(\"src/\" + keystoreProperties[\"storeFile\"] as String)"
    grep -n "storeFile" android/app/build.gradle.kts || echo "No storeFile found"
    exit 1
fi

# Test keystore access
echo ""
echo "🧪 Step 6: Testing keystore access..."
if command -v keytool >/dev/null 2>&1; then
    FINGERPRINT=$(keytool -list -v -alias "$CM_KEY_ALIAS" -keystore android/app/src/keystore.jks -storepass "$CM_KEYSTORE_PASSWORD" 2>/dev/null | grep "SHA1:" || echo "")
    if [ -n "$FINGERPRINT" ]; then
        echo "✅ Keystore access successful"
        echo "   Fingerprint: $FINGERPRINT"
    else
        echo "❌ Keystore access failed"
        exit 1
    fi
else
    echo "⚠️ keytool not available, skipping keystore access test"
fi

echo ""
echo "🎉 Keystore Path Fix Test: PASSED ✅"
echo ""
echo "📋 Summary:"
echo "- Keystore file: android/app/src/keystore.jks"
echo "- Keystore properties: android/app/src/keystore.properties"
echo "- Build.gradle.kts: Correctly configured with 'src/' prefix"
echo "- Expected Gradle path: android/app/src/keystore.jks"
echo ""
echo "🚀 Ready for Codemagic deployment!" 