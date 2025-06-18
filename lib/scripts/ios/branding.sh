#!/bin/bash
set -e

# Load environment variables from Codemagic
# These variables are injected by codemagic.yaml
APP_NAME=${APP_NAME}
LOGO_URL=${LOGO_URL}
SPLASH_URL=${SPLASH_URL}
SPLASH_BG_URL=${SPLASH_BG_URL}
SPLASH_BG_COLOR=${SPLASH_BG_COLOR}
SPLASH_TAGLINE=${SPLASH_TAGLINE}
SPLASH_TAGLINE_COLOR=${SPLASH_TAGLINE_COLOR}
SPLASH_ANIMATION=${SPLASH_ANIMATION}
SPLASH_DURATION=${SPLASH_DURATION}

# Logging function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Error handling function
handle_error() {
    log "ERROR: $1"
    exit 1
}

# Set up error handling
trap 'handle_error "Error occurred at line $LINENO"' ERR

# Start branding setup
log "Starting branding setup for $APP_NAME"

# Create necessary directories
mkdir -p ios/QuikApp/Resources/Assets.xcassets
mkdir -p ios/QuikApp/Resources/LaunchScreen.storyboard

# Download and process app icon
if [ -n "$LOGO_URL" ]; then
    log "Downloading app icon from $LOGO_URL"
    curl -L "$LOGO_URL" -o temp_icon.png || handle_error "Failed to download app icon"
    
    # Create AppIcon.appiconset
    mkdir -p ios/QuikApp/Resources/Assets.xcassets/AppIcon.appiconset
    
    # Generate different icon sizes
    sips -z 20 20 temp_icon.png --out ios/QuikApp/Resources/Assets.xcassets/AppIcon.appiconset/Icon-20.png
    sips -z 40 40 temp_icon.png --out ios/QuikApp/Resources/Assets.xcassets/AppIcon.appiconset/Icon-20@2x.png
    sips -z 60 60 temp_icon.png --out ios/QuikApp/Resources/Assets.xcassets/AppIcon.appiconset/Icon-20@3x.png
    sips -z 29 29 temp_icon.png --out ios/QuikApp/Resources/Assets.xcassets/AppIcon.appiconset/Icon-29.png
    sips -z 58 58 temp_icon.png --out ios/QuikApp/Resources/Assets.xcassets/AppIcon.appiconset/Icon-29@2x.png
    sips -z 87 87 temp_icon.png --out ios/QuikApp/Resources/Assets.xcassets/AppIcon.appiconset/Icon-29@3x.png
    sips -z 40 40 temp_icon.png --out ios/QuikApp/Resources/Assets.xcassets/AppIcon.appiconset/Icon-40.png
    sips -z 80 80 temp_icon.png --out ios/QuikApp/Resources/Assets.xcassets/AppIcon.appiconset/Icon-40@2x.png
    sips -z 120 120 temp_icon.png --out ios/QuikApp/Resources/Assets.xcassets/AppIcon.appiconset/Icon-40@3x.png
    sips -z 76 76 temp_icon.png --out ios/QuikApp/Resources/Assets.xcassets/AppIcon.appiconset/Icon-76.png
    sips -z 152 152 temp_icon.png --out ios/QuikApp/Resources/Assets.xcassets/AppIcon.appiconset/Icon-76@2x.png
    sips -z 167 167 temp_icon.png --out ios/QuikApp/Resources/Assets.xcassets/AppIcon.appiconset/Icon-83.5@2x.png
    sips -z 1024 1024 temp_icon.png --out ios/QuikApp/Resources/Assets.xcassets/AppIcon.appiconset/Icon-1024.png
    
    # Create Contents.json for AppIcon.appiconset
    cat > ios/QuikApp/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json << EOF
{
  "images" : [
    {
      "size" : "20x20",
      "idiom" : "iphone",
      "filename" : "Icon-20@2x.png",
      "scale" : "2x"
    },
    {
      "size" : "20x20",
      "idiom" : "iphone",
      "filename" : "Icon-20@3x.png",
      "scale" : "3x"
    },
    {
      "size" : "29x29",
      "idiom" : "iphone",
      "filename" : "Icon-29@2x.png",
      "scale" : "2x"
    },
    {
      "size" : "29x29",
      "idiom" : "iphone",
      "filename" : "Icon-29@3x.png",
      "scale" : "3x"
    },
    {
      "size" : "40x40",
      "idiom" : "iphone",
      "filename" : "Icon-40@2x.png",
      "scale" : "2x"
    },
    {
      "size" : "40x40",
      "idiom" : "iphone",
      "filename" : "Icon-40@3x.png",
      "scale" : "3x"
    },
    {
      "size" : "60x60",
      "idiom" : "iphone",
      "filename" : "Icon-60@2x.png",
      "scale" : "2x"
    },
    {
      "size" : "60x60",
      "idiom" : "iphone",
      "filename" : "Icon-60@3x.png",
      "scale" : "3x"
    },
    {
      "size" : "20x20",
      "idiom" : "ipad",
      "filename" : "Icon-20.png",
      "scale" : "1x"
    },
    {
      "size" : "20x20",
      "idiom" : "ipad",
      "filename" : "Icon-20@2x.png",
      "scale" : "2x"
    },
    {
      "size" : "29x29",
      "idiom" : "ipad",
      "filename" : "Icon-29.png",
      "scale" : "1x"
    },
    {
      "size" : "29x29",
      "idiom" : "ipad",
      "filename" : "Icon-29@2x.png",
      "scale" : "2x"
    },
    {
      "size" : "40x40",
      "idiom" : "ipad",
      "filename" : "Icon-40.png",
      "scale" : "1x"
    },
    {
      "size" : "40x40",
      "idiom" : "ipad",
      "filename" : "Icon-40@2x.png",
      "scale" : "2x"
    },
    {
      "size" : "76x76",
      "idiom" : "ipad",
      "filename" : "Icon-76.png",
      "scale" : "1x"
    },
    {
      "size" : "76x76",
      "idiom" : "ipad",
      "filename" : "Icon-76@2x.png",
      "scale" : "2x"
    },
    {
      "size" : "83.5x83.5",
      "idiom" : "ipad",
      "filename" : "Icon-83.5@2x.png",
      "scale" : "2x"
    },
    {
      "size" : "1024x1024",
      "idiom" : "ios-marketing",
      "filename" : "Icon-1024.png",
      "scale" : "1x"
    }
  ],
  "info" : {
    "version" : 1,
    "author" : "xcode"
  }
}
EOF
    
    rm temp_icon.png
fi

# Handle splash screen if enabled
if [ "$IS_SPLASH" = "true" ]; then
    log "Setting up splash screen"
    
    # Download splash images
    if [ -n "$SPLASH_URL" ]; then
        curl -L "$SPLASH_URL" -o ios/QuikApp/Resources/Assets.xcassets/Splash.imageset/splash.png || handle_error "Failed to download splash image"
    fi
    
    if [ -n "$SPLASH_BG_URL" ]; then
        curl -L "$SPLASH_BG_URL" -o ios/QuikApp/Resources/Assets.xcassets/SplashBackground.imageset/splash_bg.png || handle_error "Failed to download splash background"
    fi
    
    # Create LaunchScreen.storyboard
    cat > ios/QuikApp/Resources/LaunchScreen.storyboard << EOF
<?xml version="1.0" encoding="UTF-8"?>
<document type="com.apple.InterfaceBuilder3.CocoaTouch.Storyboard.XIB" version="3.0" toolsVersion="21507" targetRuntime="iOS.CocoaTouch" propertyAccessControl="none" useAutolayout="YES" launchScreen="YES" useTraitCollections="YES" useSafeAreas="YES" colorMatched="YES" initialViewController="01J-lp-oVM">
    <device id="retina6_12" orientation="portrait" appearance="light"/>
    <dependencies>
        <plugIn identifier="com.apple.InterfaceBuilder.IBCocoaTouchPlugin" version="21505"/>
        <capability name="Safe area layout guides" minToolsVersion="9.0"/>
        <capability name="documents saved in the Xcode 8 format" minToolsVersion="8.0"/>
    </dependencies>
    <scenes>
        <scene sceneID="EHf-IW-A2E">
            <objects>
                <viewController id="01J-lp-oVM" sceneMemberID="viewController">
                    <view key="view" contentMode="scaleToFill" id="Ze5-6b-2t3">
                        <rect key="frame" x="0.0" y="0.0" width="393" height="852"/>
                        <autoresizingMask key="autoresizingMask" widthSizable="YES" heightSizable="YES"/>
                        <subviews>
                            <imageView clipsSubviews="YES" userInteractionEnabled="NO" contentMode="scaleAspectFit" horizontalHuggingPriority="251" verticalHuggingPriority="251" image="Splash" translatesAutoresizingMaskIntoConstraints="NO" id="YRO-k0-Ey4">
                                <rect key="frame" x="96.666666666666686" y="326" width="200" height="200"/>
                                <constraints>
                                    <constraint firstAttribute="width" constant="200" id="3T2-ad-Qdv"/>
                                    <constraint firstAttribute="height" constant="200" id="Z3M-gh-QbE"/>
                                </constraints>
                            </imageView>
                            <label opaque="NO" userInteractionEnabled="NO" contentMode="left" horizontalHuggingPriority="251" verticalHuggingPriority="251" text="$SPLASH_TAGLINE" textAlignment="center" lineBreakMode="tailTruncation" baselineAdjustment="alignBaselines" adjustsFontSizeToFit="NO" translatesAutoresizingMaskIntoConstraints="NO" id="f7c-gh-QbE">
                                <rect key="frame" x="20" y="546" width="353" height="21"/>
                                <fontDescription key="fontDescription" type="system" weight="semibold" pointSize="17"/>
                                <color key="textColor" $SPLASH_TAGLINE_COLOR/>
                                <nil key="highlightedColor"/>
                            </label>
                        </subviews>
                        <viewLayoutGuide key="safeArea" id="6Tk-OE-BBY"/>
                        <color key="backgroundColor" $SPLASH_BG_COLOR/>
                        <constraints>
                            <constraint firstItem="YRO-k0-Ey4" firstAttribute="centerX" secondItem="Ze5-6b-2t3" secondAttribute="centerX" id="1a2-6s-vTC"/>
                            <constraint firstItem="YRO-k0-Ey4" firstAttribute="centerY" secondItem="Ze5-6b-2t3" secondAttribute="centerY" id="4X2-HB-R7a"/>
                            <constraint firstItem="f7c-gh-QbE" firstAttribute="top" secondItem="YRO-k0-Ey4" secondAttribute="bottom" constant="20" id="6zV-gh-QbE"/>
                            <constraint firstItem="f7c-gh-QbE" firstAttribute="leading" secondItem="6Tk-OE-BBY" secondAttribute="leading" constant="20" id="7zV-gh-QbE"/>
                            <constraint firstItem="6Tk-OE-BBY" firstAttribute="trailing" secondItem="f7c-gh-QbE" secondAttribute="trailing" constant="20" id="8zV-gh-QbE"/>
                        </constraints>
                    </view>
                </viewController>
                <placeholder placeholderIdentifier="IBFirstResponder" id="iYj-Kq-Ea1" userLabel="First Responder" sceneMemberID="firstResponder"/>
            </objects>
            <point key="canvasLocation" x="53" y="375"/>
        </scene>
    </scenes>
    <resources>
        <image name="Splash" width="200" height="200"/>
    </resources>
</document>
EOF
fi

# Update Info.plist with app name
if [ -n "$APP_NAME" ]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $APP_NAME" ios/QuikApp/Info.plist
    /usr/libexec/PlistBuddy -c "Set :CFBundleName $APP_NAME" ios/QuikApp/Info.plist
fi

log "Branding setup completed successfully"
exit 0 