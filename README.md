# AVP MVD Watcher Menu Bar

<p align="center">
  <img src="images/app-icon.png" alt="AVP MVD Watcher Menu Bar Icon" width="600" />
</p>

<p align="center">
  <img src="images/avp-mvd-screenshot.png" alt="AVP MVD Watcher Menu Bar Screenshot" width="600" />
</p>

A native macOS menu bar utility built in SwiftUI that displays whether your Mac is ready to connect to the Apple Vision Pro (AVP) feature **Mac Virtual Display (MVD)**.

## Features

- **Monochrome Status Icon**: Follows macOS menu bar guidelines with a clean Apple Vision Pro headset symbol (`visionpro`).
  - Shows the standard headset icon when all systems are ready.
  - Shows the badge icon (`visionpro.badge.exclamationmark`) when any system is offline.
- **Adaptive Check Frequencies**:
  - Automatically checks status every **30 seconds** when all systems are go.
  - Switches to a **10-second** refresh rate when at least one system is down to support active troubleshooting.
- **Detailed Dropdown Menu**: Clicking the status icon displays individual status indicators with green/red status dots:
  - **Bluetooth Status** (using `IOBluetooth` to check controller power).
  - **Wi-Fi Status** (using `CoreWLAN` and BSD sockets to check interface IP address).
  - **Keychain Status** (using Keychain API calls to ensure responsiveness of security services).
- **Manual Control**: Force an immediate update via the "Check Now" button.
- **100% Native**: Performs all checks without launching external shell processes.

## Prerequisites

- macOS 14.0 or newer.
- Xcode 15+ or Xcode Command Line Tools.

## Compilation & Installation

1. Open your terminal in the project root:
   ```bash
   cd ~/code/avp-mvd-menu-bar
   ```
2. Run the installation script:
   ```bash
   ./scripts/install.sh
   ```

This will automatically package the application, terminate any running instances, install it to `/Applications/AVPMVDMenuBar.app`, launch the utility, and register it to start automatically upon system login.
