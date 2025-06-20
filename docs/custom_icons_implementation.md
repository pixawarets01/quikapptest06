# Custom Icons Implementation for Bottom Menu Bar

## Overview

The QuikApp build system now supports custom SVG icons for the bottom navigation bar, allowing you to use both preset Material Design icons and custom SVG icons loaded from URLs.

## Features

✅ **Dual Icon Support**: Both preset Material Design icons and custom SVG icons  
✅ **Automatic Download**: Custom icons are automatically downloaded during build  
✅ **Asset Management**: Icons are stored in `assets/icons/` folder  
✅ **Backward Compatibility**: Supports legacy string-based icon format  
✅ **Loading States**: Shows loading indicators while custom icons download  
✅ **Error Handling**: Graceful fallback to error icons if download fails

## Icon Format Support

### 1. Preset Icons (Material Design)

```json
{
  "label": "Home",
  "icon": {
    "type": "preset",
    "name": "home_outlined"
  },
  "url": "https://example.com/"
}
```

### 2. Custom SVG Icons

```json
{
  "label": "Services",
  "icon": {
    "type": "custom",
    "icon_url": "https://raw.githubusercontent.com/user/repo/main/icon.svg",
    "icon_size": "24"
  },
  "url": "https://example.com/services/"
}
```

### 3. Legacy Format (Backward Compatible)

```json
{
  "label": "Home",
  "icon": "home",
  "url": "https://example.com/"
}
```

## Implementation Details

### Build Process Integration

The custom icons download is integrated into all build workflows and **only runs when `IS_BOTTOMMENU=true`**:

1. **Android Build** (`lib/scripts/android/main.sh`)
2. **iOS Build** (`lib/scripts/ios/main.sh`)
3. **Combined Build** (`lib/scripts/combined/main.sh`)

### Conditional Execution

- ✅ **When `IS_BOTTOMMENU=true`**: Downloads custom icons and validates them
- ⏭️ **When `IS_BOTTOMMENU=false`**: Skips the entire custom icons download process
- 📝 **Logs**: Clear indication of whether the process was skipped or executed

### Download Script

**File**: `lib/scripts/utils/download_custom_icons.sh`

**Features**:

- Parses `BOTTOMMENU_ITEMS` JSON configuration
- Downloads custom SVG icons to `assets/icons/` folder
- Sanitizes filenames (lowercase, underscores)
- Validates downloads and provides error handling
- Skips existing files to avoid redundant downloads

### Flutter Implementation

**File**: `lib/module/main_home.dart`

**Key Components**:

1. **`buildMenuIcon()` Function**:

   - Handles all three icon formats
   - Downloads custom icons to `assets/icons/`
   - Uses `SvgPicture.asset()` for loaded icons
   - Provides loading states and error fallbacks

2. **`BottomNavigationBar` Integration**:

   - Uses `FutureBuilder` for async icon loading
   - Shows loading indicators during download
   - Applies custom colors and styling
   - Supports `BottomNavigationBarType.fixed` for 4+ items

3. **Text Styling**:
   - Uses `EnvConfig` variables for font customization
   - Supports Google Fonts integration
   - Applies custom colors for active/inactive states

## Configuration Variables

### Required Variables

```bash
BOTTOMMENU_ITEMS='[{"label":"Home","icon":{"type":"preset","name":"home"},"url":"https://example.com/"}]'
```

### Optional Styling Variables

```bash
BOTTOMMENU_BG_COLOR="#FFFFFF"
BOTTOMMENU_ICON_COLOR="#6d6e8c"
BOTTOMMENU_TEXT_COLOR="#6d6e8c"
BOTTOMMENU_FONT="DM Sans"
BOTTOMMENU_FONT_SIZE="12"
BOTTOMMENU_FONT_BOLD="false"
BOTTOMMENU_FONT_ITALIC="false"
BOTTOMMENU_ACTIVE_TAB_COLOR="#a30237"
BOTTOMMENU_ICON_POSITION="above"
```

## Example Configuration

### Complete Bottom Menu Configuration

```json
{
  "BOTTOMMENU_ITEMS": "[{\"label\":\"Home\",\"icon\":{\"type\":\"preset\",\"name\":\"home_outlined\"},\"url\":\"https://pixaware.co/\"},{\"label\":\"services\",\"icon\":{\"type\":\"custom\",\"icon_url\":\"https://raw.githubusercontent.com/prasanna91/QuikApp/main/card.svg\",\"icon_size\":\"24\"},\"url\":\"https://pixaware.co/solutions/\"},{\"label\":\"About\",\"icon\":{\"type\":\"custom\",\"icon_url\":\"https://raw.githubusercontent.com/prasanna91/QuikApp/main/about.svg\",\"icon_size\":\"24\"},\"url\":\"https://pixaware.co/who-we-are/\"},{\"label\":\"Contact\",\"icon\":{\"type\":\"custom\",\"icon_url\":\"https://raw.githubusercontent.com/prasanna91/QuikApp/main/contact.svg\",\"icon_size\":\"24\"},\"url\":\"https://pixaware.co/lets-talk/\"}]",
  "BOTTOMMENU_BG_COLOR": "#FFFFFF",
  "BOTTOMMENU_ICON_COLOR": "#6d6e8c",
  "BOTTOMMENU_TEXT_COLOR": "#6d6e8c",
  "BOTTOMMENU_FONT": "DM Sans",
  "BOTTOMMENU_FONT_SIZE": "12",
  "BOTTOMMENU_FONT_BOLD": "false",
  "BOTTOMMENU_FONT_ITALIC": "false",
  "BOTTOMMENU_ACTIVE_TAB_COLOR": "#a30237",
  "BOTTOMMENU_ICON_POSITION": "above"
}
```

## Build Process Flow

1. **Branding Step**: Downloads app logo and splash screen
2. **Custom Icons Download**: Downloads SVG icons to `assets/icons/`
3. **Customization Step**: Applies app name, package ID, and icon
4. **Permissions Step**: Configures app permissions
5. **Firebase/Keystore Step**: Platform-specific setup
6. **Build Step**: Generates APK/AAB/IPA with custom icons

## File Structure

```
assets/
├── icons/                    # Custom SVG icons storage
│   ├── home.svg             # Downloaded from icon_url
│   ├── services.svg         # Downloaded from icon_url
│   └── about.svg            # Downloaded from icon_url
├── images/
│   ├── logo.png             # App logo
│   └── splash.png           # Splash screen
```

## Error Handling

### Download Failures

- Shows error icon if SVG download fails
- Logs detailed error messages
- Continues build process with fallback icons

### Invalid JSON

- Validates JSON format before processing
- Provides clear error messages for malformed configuration
- Falls back to default icons

### Missing Files

- Creates `assets/icons/` directory if it doesn't exist
- Handles missing icon files gracefully
- Uses placeholder icons for missing assets

## Performance Optimizations

1. **Caching**: Icons are downloaded once and cached in `assets/icons/`
2. **Parallel Processing**: Icon downloads happen in parallel during build
3. **Lazy Loading**: Icons are loaded only when needed in the UI
4. **Asset Optimization**: SVG files are optimized for mobile rendering

## Troubleshooting

### Common Issues

1. **Icons Not Loading**:

   - Check `assets/icons/` directory exists
   - Verify SVG URLs are accessible
   - Check build logs for download errors
   - **Verify `IS_BOTTOMMENU=true`** if using bottom menu

2. **Build Failures**:

   - Ensure `BOTTOMMENU_ITEMS` is valid JSON
   - Check icon URLs are publicly accessible
   - Verify network connectivity during build
   - **Check `IS_BOTTOMMENU` setting** - icons only download when enabled

3. **Styling Issues**:

   - Confirm font variables are set correctly
   - Check color values are valid hex codes
   - Verify Google Fonts integration

4. **Custom Icons Not Downloaded**:
   - **Ensure `IS_BOTTOMMENU=true`** in your configuration
   - Check build logs for "Bottom menu disabled" message
   - Verify `BOTTOMMENU_ITEMS` contains custom icon entries
   - Confirm icon URLs are accessible and return valid SVG content

### Debug Commands

```bash
# Check if icons directory exists
ls -la assets/icons/

# Test icon download manually
curl -I https://raw.githubusercontent.com/user/repo/main/icon.svg

# Validate JSON format
echo "$BOTTOMMENU_ITEMS" | python3 -m json.tool
```

## Future Enhancements

- [ ] Icon caching with version control
- [ ] Support for PNG/JPG custom icons
- [ ] Icon optimization and compression
- [ ] Dynamic icon loading from CDN
- [ ] Icon animation support
- [ ] Dark/light theme icon variants

## Support

For issues with custom icons implementation:

1. Check build logs for error messages
2. Verify JSON configuration format
3. Test icon URLs manually
4. Review asset directory structure
5. Contact QuikApp support team
