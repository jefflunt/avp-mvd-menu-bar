#!/bin/bash
set -e

# Navigate to the repository root
cd "$(dirname "$0")/.."

echo "Running packaging script..."
./scripts/package.sh

echo "Killing any running version of AVPMVDMenuBar..."
pkill -x "AVPMVDMenuBar" || true

APP_PATH=".build/release/AVPMVDMenuBar.app"

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

echo "Starting AVPMVDMenuBar..."
open "/Applications/AVPMVDMenuBar.app"

echo "Adding AVPMVDMenuBar to system Login Items..."
if osascript -e 'tell application "System Events" to if exists login item "AVPMVDMenuBar" then delete login item "AVPMVDMenuBar"' && \
   osascript -e 'tell application "System Events" to make new login item at end with properties {name: "AVPMVDMenuBar", path: "/Applications/AVPMVDMenuBar.app", hidden: false}'; then
    echo "Successfully registered as a Login Item."
else
    echo "Warning: Could not add application to Login Items. This might be due to missing Automation/System Events permissions, or running in a headless terminal."
fi

echo "Successfully installed and started AVPMVDMenuBar.app."
