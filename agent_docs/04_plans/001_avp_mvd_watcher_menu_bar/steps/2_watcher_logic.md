# Step 2: Watcher Logic

Implement the native checking logic in `AVPMVDWatcher.swift`.

## Tasks
1. Implement Bluetooth check using `IOBluetoothHostController.default()?.powerState`.
2. Implement Wi-Fi check resolving interface name with `CWWiFiClient` and fetching interface IP using `getifaddrs`.
3. Implement Keychain check via `SecItemCopyMatching` verifying keychain responsiveness.
4. Implement `AVPMVDWatcher` as an `ObservableObject`:
   - Runs these checks asynchronously.
   - Manages the dynamic timer (30s interval when all online, 10s when any system is offline).

## Files
- `Sources/AVPMVDWatcher.swift` [NEW]
