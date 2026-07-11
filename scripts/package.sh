#!/bin/bash
set -e

# Navigate to the repository root
cd "$(dirname "$0")/.."

echo "Building AVP MVD Watcher Menu Bar in release mode..."
swift build -c release

APP_DIR=".build/release/AVPMVDMenuBar.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "Creating App Bundle structure for 'AVPMVDMenuBar'..."
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

echo "Copying binary to App Bundle..."
cp ".build/release/AVPMVDMenuBar" "$MACOS_DIR/AVPMVDMenuBar"

if [ -f "Resources/AppIcon.icns" ]; then
    echo "Copying AppIcon.icns to App Bundle..."
    cp "Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

echo "Writing Info.plist..."
cat <<EOF > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>AVPMVDMenuBar</string>
    <key>CFBundleIdentifier</key>
    <string>com.jefflunt.avpmvdmenubar</string>
    <key>CFBundleName</key>
    <string>AVPMVDMenuBar</string>
    <key>CFBundleDisplayName</key>
    <string>AVPMVDMenuBar</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSBluetoothAlwaysUsageDescription</key>
    <string>This utility checks Bluetooth status to verify if your Mac is ready to host a Mac Virtual Display session.</string>
</dict>
</plist>
EOF

echo "Applying ad-hoc code signature..."
codesign --force --deep --sign - "$APP_DIR"

echo "Application packaged successfully at:"
echo "  $APP_DIR"
