#!/bin/bash

# Build script for Recall without Xcode IDE
# Requires: Xcode Command Line Tools or Xcode installed

set -e

echo "Building Recall..."

# Get SDK path
SDK_PATH=$(xcrun --show-sdk-path --sdk macosx)

# Build directory
BUILD_DIR="build"
APP_NAME="Recall"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"

# Clean and create build directory
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

# Create app bundle structure
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# Copy app icon
cp Sources/Assets.xcassets/AppIcon.icns "${APP_BUNDLE}/Contents/Resources/"

# Copy status bar icon
cp Sources/StatusBarIcon.png "${APP_BUNDLE}/Contents/Resources/"

# Copy and process Info.plist (replace Xcode variables)
cp Sources/Info.plist "${APP_BUNDLE}/Contents/Info.plist"
sed -i '' 's/\$(EXECUTABLE_NAME)/'"${APP_NAME}"'/g' "${APP_BUNDLE}/Contents/Info.plist"
sed -i '' 's/\$(PRODUCT_NAME)/'"${APP_NAME}"'/g' "${APP_BUNDLE}/Contents/Info.plist"
sed -i '' 's/\$(PRODUCT_BUNDLE_IDENTIFIER)/com.example.Recall/g' "${APP_BUNDLE}/Contents/Info.plist"
sed -i '' 's/\$(DEVELOPMENT_LANGUAGE)/en/g' "${APP_BUNDLE}/Contents/Info.plist"
sed -i '' 's/\$(PRODUCT_BUNDLE_PACKAGE_TYPE)/APPL/g' "${APP_BUNDLE}/Contents/Info.plist"
sed -i '' 's/\$(MACOSX_DEPLOYMENT_TARGET)/12.0/g' "${APP_BUNDLE}/Contents/Info.plist"

# Add app icon reference to Info.plist
/usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "${APP_BUNDLE}/Contents/Info.plist" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon" "${APP_BUNDLE}/Contents/Info.plist"

# Compile Swift files
echo "Compiling Swift sources..."
swiftc \
    -sdk "${SDK_PATH}" \
    -target x86_64-apple-macosx12.0 \
    -O \
    -whole-module-optimization \
    -framework AppKit \
    -framework Carbon \
    -o "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}" \
    Sources/main.swift \
    Sources/AppDelegate.swift \
    Sources/ClipboardMonitor.swift \
    Sources/ClipboardStore.swift \
    Sources/HotkeyManager.swift \
    Sources/StatusBarController.swift \
    Sources/ClipboardPanel.swift \
    Sources/ClipboardEntry.swift

# Set executable bit
chmod +x "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

# Strip symbols to reduce size
echo "Stripping symbols..."
strip -x "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

# Sign the executable first
echo "Signing executable..."
codesign --force --sign - "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

# Then sign the app bundle with entitlements
echo "Signing application bundle..."
codesign --force --deep --sign - --entitlements Recall.entitlements "${APP_BUNDLE}"

echo ""
echo "✅ Build successful!"
echo ""
echo "Application: Recall"
echo "Bundle: ${APP_BUNDLE}"
echo ""
echo "To run:"
echo "  open ${APP_BUNDLE}"
echo ""
