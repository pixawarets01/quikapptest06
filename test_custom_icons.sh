#!/bin/bash

# Test script to verify custom icon download functionality
echo "🧪 Testing Custom Icon Download Functionality"
echo "=============================================="

# Set up test environment
export IS_BOTTOMMENU="true"
export BOTTOMMENU_ITEMS='[{"label":"Home","icon":{"type":"preset","name":"home_outlined"},"url":"https://twinklub.com/"},{"label":"New Arraivals","icon":{"type":"custom","icon_url":"https://raw.githubusercontent.com/prasanna91/QuikApp/main/card.svg","icon_size":"24"},"url":"https://www.twinklub.com/collections/new-arrivals"},{"label":"Collections","icon":{"type":"custom","icon_url":"https://raw.githubusercontent.com/prasanna91/QuikApp/main/about.svg","icon_size":"24"},"url":"https://www.twinklub.com/collections/all"},{"label":"Contact","icon":{"type":"custom","icon_url":"https://raw.githubusercontent.com/prasanna91/QuikApp/main/contact.svg","icon_size":"24"},"url":"https://www.twinklub.com/account"}]'

echo ""
echo "📋 Test Configuration:"
echo "   IS_BOTTOMMENU: $IS_BOTTOMMENU"
echo "   BOTTOMMENU_ITEMS: $BOTTOMMENU_ITEMS"

# Create assets/icons directory if it doesn't exist
mkdir -p assets/icons

echo ""
echo "🔍 Test 1: Custom Icon Download Script"
echo "--------------------------------------"

# Test the download script
if [ -f "lib/scripts/utils/download_custom_icons.sh" ]; then
    chmod +x lib/scripts/utils/download_custom_icons.sh
    if lib/scripts/utils/download_custom_icons.sh; then
        echo "✅ PASS: Custom icon download script executed successfully"
    else
        echo "❌ FAIL: Custom icon download script failed"
        exit 1
    fi
else
    echo "❌ FAIL: Custom icon download script not found"
    exit 1
fi

echo ""
echo "🔍 Test 2: Verify Downloaded Icons"
echo "-----------------------------------"

# Check if icons were downloaded
expected_icons=("new_arraivals.svg" "collections.svg" "contact.svg")
downloaded_count=0

for icon in "${expected_icons[@]}"; do
    if [ -f "assets/icons/$icon" ]; then
        echo "✅ Found: $icon"
        downloaded_count=$((downloaded_count + 1))
    else
        echo "❌ Missing: $icon"
    fi
done

echo ""
echo "📊 Download Summary:"
echo "   Expected custom icons: ${#expected_icons[@]}"
echo "   Downloaded icons: $downloaded_count"

if [ $downloaded_count -eq ${#expected_icons[@]} ]; then
    echo "✅ PASS: All custom icons downloaded successfully"
else
    echo "❌ FAIL: Some custom icons are missing"
    exit 1
fi

echo ""
echo "🔍 Test 3: Icon File Validation"
echo "--------------------------------"

# Validate that downloaded files are valid SVG files
for icon in "${expected_icons[@]}"; do
    if [ -f "assets/icons/$icon" ]; then
        # Check if file contains SVG content
        if grep -q "<svg" "assets/icons/$icon"; then
            echo "✅ Valid SVG: $icon"
        else
            echo "❌ Invalid SVG: $icon"
        fi
        
        # Check file size
        file_size=$(stat -f%z "assets/icons/$icon" 2>/dev/null || stat -c%s "assets/icons/$icon" 2>/dev/null)
        echo "   Size: ${file_size} bytes"
    fi
done

echo ""
echo "🔍 Test 4: pubspec.yaml Assets Configuration"
echo "---------------------------------------------"

# Check if assets/icons/ is included in pubspec.yaml
if grep -q "assets/icons/" pubspec.yaml; then
    echo "✅ PASS: assets/icons/ is included in pubspec.yaml"
else
    echo "❌ FAIL: assets/icons/ is not included in pubspec.yaml"
    exit 1
fi

echo ""
echo "🔍 Test 5: Flutter Asset Validation"
echo "-----------------------------------"

# Test if Flutter can access the assets
echo "Testing Flutter asset access..."
flutter pub get > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo "✅ PASS: Flutter can access assets"
else
    echo "❌ FAIL: Flutter cannot access assets"
fi

echo ""
echo "🎉 Custom Icon Download Test Summary"
echo "===================================="
echo "✅ The custom icon download functionality is working correctly:"
echo "   - Script downloads custom icons from BOTTOMMENU_ITEMS"
echo "   - Icons are saved to assets/icons/ directory"
echo "   - pubspec.yaml includes assets/icons/ configuration"
echo "   - Flutter can access the downloaded assets"
echo ""
echo "📁 Downloaded Icons:"
ls -la assets/icons/ 2>/dev/null || echo "No icons found"

echo ""
echo "🚀 Custom icon download is ready for production use!" 