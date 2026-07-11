# Step 3: UI Implementation

Connect the watcher to the menu bar UI using SwiftUI and dynamic menu items.

## Tasks
1. Declare the application entry point using `@main` with an `App` structure.
2. Initialize `AVPMVDWatcher` as a `@StateObject`.
3. Set the application's activation policy to `.accessory` in the `init()` method of the App.
4. Implement the `MenuBarExtra` scene with the dynamic monochrome icons:
   - `visionpro`: All systems OK
   - `visionpro.badge.exclamationmark`: Offline component(s)
   - `visionpro.slash`: Error running script
5. Build the dropdown menu:
   - Show individual status rows for Bluetooth, Wi-Fi, and Keychain with checkmarks/crosses or descriptive status text based on exit code bitmask.
   - Show "Check Now" button.
   - Show last checked timestamp.
   - Show "Quit" button.

## Files
- `Sources/AVPMVDMenuBarApp.swift` [NEW]
