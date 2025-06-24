#!/bin/bash

# Test script to verify environment configuration generation
echo "🧪 Testing Environment Configuration Generation..."

# Set test environment variables
export OUTPUT_DIR="test_output/ios"
export PROJECT_ROOT="$(pwd)"
export CM_BUILD_DIR="$(pwd)"
export APP_NAME="TestApp"
export VERSION_NAME="1.0.0"
export VERSION_CODE="1"
export WORKFLOW_ID="ios-test"
export BUNDLE_ID="com.test.app"
export PUSH_NOTIFY="false"
export CERT_PASSWORD="test"
export PROFILE_TYPE="app-store"

echo "📋 Test Environment Variables:"
echo "   OUTPUT_DIR: $OUTPUT_DIR"
echo "   PROJECT_ROOT: $PROJECT_ROOT"
echo "   CM_BUILD_DIR: $CM_BUILD_DIR"

# Run the environment configuration generator
if [ -f "lib/scripts/utils/gen_env_config.sh" ]; then
    chmod +x lib/scripts/utils/gen_env_config.sh
    source lib/scripts/utils/gen_env_config.sh
    if generate_env_config; then
        echo "✅ Environment configuration generated successfully"
        
        # Check if OUTPUT_DIR was set correctly
        if grep -q "static const String outputDir = \"test_output/ios\";" lib/config/env_config.dart; then
            echo "✅ OUTPUT_DIR set correctly in env_config.dart"
        else
            echo "❌ OUTPUT_DIR not set correctly in env_config.dart"
            echo "📄 Current outputDir value:"
            grep "static const String outputDir" lib/config/env_config.dart
        fi
    else
        echo "❌ Failed to generate environment configuration"
        exit 1
    fi
else
    echo "❌ Environment configuration generator not found"
    exit 1
fi

echo "�� Test completed!" 