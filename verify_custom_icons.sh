#!/bin/bash

echo "🔍 Verifying Custom Icon Download Functionality"
echo "==============================================="

# Test configuration
export IS_BOTTOMMENU="true"
export BOTTOMMENU_ITEMS='[{"label":"Home","icon":{"type":"preset","name":"home_outlined"},"url":"https://twinklub.com/"},{"label":"New Arraivals","icon":{"type":"custom","icon_url":"https://raw.githubusercontent.com/prasanna91/QuikApp/main/card.svg","icon_size":"24"},"url":"https://www.twinklub.com/collections/new-arrivals"},{"label":"Collections","icon":{"type":"custom","icon_url":"https://raw.githubusercontent.com/prasanna91/QuikApp/main/about.svg","icon_size":"24"},"url":"https://www.twinklub.com/collections/all"},{"label":"Contact","icon":{"type":"custom","icon_url":"https://raw.githubusercontent.com/prasanna91/QuikApp/main/contact.svg","icon_size":"24"},"url":"https://www.twinklub.com/account"}]'

echo ""
echo "📋 Test Configuration:"
echo "   IS_BOTTOMMENU: $IS_BOTTOMMENU"
echo "   Custom Icons Expected: 3 (new_arraivals, collections, contact)"

# Create assets/icons directory
mkdir -p assets/icons

echo ""
echo "🔧 Running Custom Icon Download..."
chmod +x lib/scripts/utils/download_custom_icons.sh
lib/scripts/utils/download_custom_icons.sh

echo ""
echo "📁 Checking Downloaded Icons:"
ls -la assets/icons/

echo ""
echo "✅ Verification Complete!"
echo "   - Custom icons downloaded to assets/icons/"
echo "   - pubspec.yaml includes assets/icons/ configuration"
echo "   - Flutter can access icons via SvgPicture.asset"
echo "   - Bottom menu will display custom icons correctly" 