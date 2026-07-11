#!/bin/bash
set -e

# Navigate to the repository root
cd "$(dirname "$0")/.."

APP_PATH=".build/release/AVPMVDMenuBar.app"

# Build/package first if it does not exist
if [ ! -d "$APP_PATH" ]; then
    echo "Application not built yet. Running packaging script..."
    ./scripts/package.sh
fi

echo "Installing AVPMVDMenuBar to /Applications..."

# Check if we have write permission to /Applications
if [ -w "/Applications" ]; then
    # Remove existing app if present to avoid permission/nesting issues
    rm -rf "/Applications/AVPMVDMenuBar.app"
    cp -R "$APP_PATH" "/Applications/"
else
    echo "Write permission to /Applications is required. Prompting for administrator privileges (sudo)..."
    sudo rm -rf "/Applications/AVPMVDMenuBar.app"
    sudo cp -R "$APP_PATH" "/Applications/"
fi

echo "Adding AVPMVDMenuBar to system Login Items..."
if osascript -e 'tell application "System Events" to if exists login item "AVPMVDMenuBar" then delete login item "AVPMVDMenuBar"' && \
   osascript -e 'tell application "System Events" to make new login item at end with properties {name: "AVPMVDMenuBar", path: "/Applications/AVPMVDMenuBar.app", hidden: false}'; then
    echo "Successfully registered as a Login Item."
else
    echo "Warning: Could not add application to Login Items. This might be due to missing Automation/System Events permissions, or running in a headless terminal."
fi

echo "Checking if AVPMVDMenuBar is running..."
if ! pgrep -x "AVPMVDMenuBar" > /dev/null; then
    echo "Starting AVPMVDMenuBar..."
    open "/Applications/AVPMVDMenuBar.app"
else
    echo "AVPMVDMenuBar is already running."
fi

echo "Successfully installed AVPMVDMenuBar.app to /Applications."
