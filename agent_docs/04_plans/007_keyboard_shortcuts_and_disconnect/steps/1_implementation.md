# Step 1: Implementation of Keyboard Shortcuts, Disconnect, and Unit Test Backfill

## Tasks
1. Refactor `Package.swift` to:
   - Split `Sources` into `AVPMVDCore` (library) and `AVPMVDMenuBar` (executable) targets by specifying explicit `sources` arrays.
   - Add a test target `AVPMVDMenuBarTests` pointing to `Tests`.
2. Define testing protocols in `Sources/AVPMVDWatcher.swift`:
   - `BluetoothMonitor`, `WifiMonitor`, `KeychainMonitor`, `ScreenMonitor`, `BonjourBrowser`, and `ScriptExecutor`.
3. Move real implementations into wrapper classes satisfying these protocols.
4. Modify `AVPMVDWatcher` constructor to accept these dependencies with default arguments of the production wrapper classes.
5. In `AVPMVDWatcher.swift`, implement `disconnectMVD()` using the `ScriptExecutor` dependency.
6. Replace the static connected status label in `Sources/AVPMVDMenuBarApp.swift` with a `Button` linking to `watcher.disconnectMVD()`.
7. Add `.keyboardShortcut("c", modifiers: [.command, .option])` for connecting, and `.keyboardShortcut("d", modifiers: [.command, .option])` for disconnecting, to their respective buttons in `Sources/AVPMVDMenuBarApp.swift`.
8. Create `Tests/AVPMVDWatcherTests.swift` and implement mock versions of all protocols.
9. Implement unit tests for:
   - State updates when individual services (Bluetooth, Wifi, Keychain, Bonjour discovery, MVD screen connection) toggle.
   - Menu bar icon logic for all combinations.
   - Connection/Disconnection AppleScript execution parameter/body verification.
   - Last check time formatted string accuracy.
