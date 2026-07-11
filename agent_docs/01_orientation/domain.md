# Domain

## Core Concepts

### Mac Virtual Display (MVD)
An Apple Vision Pro feature that allows projecting a Mac screen onto a virtual canvas inside the Vision Pro headset. This feature requires Bluetooth, Wi-Fi, and Keychain services to be active and properly configured on the host Mac.

### System Readiness
- **Bluetooth**: Must be powered on (state == `kBluetoothHCIPowerStateON`).
- **Wi-Fi**: Must have an active interface (typically `en0`) and a valid local IP address assigned.
- **Keychain**: The Keychain daemon (`securityd`) must be responsive to queries.

### Watcher Polling
- **Healthy state**: Checks repeat every 30 seconds.
- **Unhealthy state**: Checks repeat every 10 seconds to prompt user troubleshooting and quickly capture recovery.
