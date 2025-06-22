#!/bin/bash

echo "Testing custom icon download..."

# Set environment variables
export IS_BOTTOMMENU="true"
export BOTTOMMENU_ITEMS='[{"label":"Home","icon":{"type":"preset","name":"home_outlined"},"url":"https://twinklub.com/"},{"label":"New Arraivals","icon":{"type":"custom","icon_url":"https://raw.githubusercontent.com/prasanna91/QuikApp/main/card.svg","icon_size":"24"},"url":"https://www.twinklub.com/collections/new-arrivals"},{"label":"Collections","icon":{"type":"custom","icon_url":"https://raw.githubusercontent.com/prasanna91/QuikApp/main/about.svg","icon_size":"24"},"url":"https://www.twinklub.com/collections/all"},{"label":"Contact","icon":{"type":"custom","icon_url":"https://raw.githubusercontent.com/prasanna91/QuikApp/main/contact.svg","icon_size":"24"},"url":"https://www.twinklub.com/account"}]'

# Create assets/icons directory
mkdir -p assets/icons

# Run the download script
chmod +x lib/scripts/utils/download_custom_icons.sh
lib/scripts/utils/download_custom_icons.sh

# Check results
echo "Checking downloaded icons..."
ls -la assets/icons/

echo "Test completed!" 