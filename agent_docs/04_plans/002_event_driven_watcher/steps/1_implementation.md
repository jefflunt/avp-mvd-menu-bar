# Step 1: Implementation of Event-Driven Watcher

## Tasks
1. Import `CoreBluetooth`, `Network`, and `AppKit` in `AVPMVDWatcher.swift`.
2. Implement `CBCentralManagerDelegate` on `AVPMVDWatcher` or a nested helper class to observe Bluetooth power state changes.
3. Add `NWPathMonitor` instance to observe Wi-Fi status changes and IP configuration.
4. Listen for `NSApplication.protectedDataDidBecomeAvailableNotification` and `NSApplication.protectedDataWillBecomeUnavailableNotification` notifications.
5. Provide a manual check method `runCheck()` that queries states on-demand when clicked.
6. Remove the `Timer` polling loop entirely.
