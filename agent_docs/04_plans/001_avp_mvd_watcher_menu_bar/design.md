# Design Specification: AVP Mac Virtual Display Watcher Menu Bar (Native)

A lightweight macOS menu bar utility built in SwiftUI that indicates whether the Mac is ready to connect to Apple Vision Pro (AVP) Mac Virtual Display (MVD).

## User Story
As an Apple Vision Pro and Mac user, I want a quick, glanceable menu bar utility that tells me if my Mac is prepared to host a Mac Virtual Display (MVD) session, so that I can troubleshoot any connectivity or system issues (Bluetooth, Wi-Fi, Keychain) before attempting to connect.

## Backlog / Requirements
1. **100% Native Checks**:
   - Query Bluetooth controller state via native `IOBluetooth` APIs.
   - Query Wi-Fi interface and retrieve active IP address using `CoreWLAN` and `getifaddrs` BSD APIs.
   - Query Keychain responsiveness via native `Security` framework calls (`SecItemCopyMatching`).
2. **Mac App Store Sandbox Compatibility**:
   - Zero subprocess spawning (`Process`). The utility is fully compatible with Mac App Store sandboxing.
3. **Adaptive Interval**:
   - Update frequency must be **30 seconds** when all check items are ONLINE/ACTIVE.
   - Update frequency must increase to **10 seconds** when at least one system is offline.
4. **Adaptive Monochrome Menu Bar Icon**:
   - Show `visionpro` (standard monochrome icon, matching macOS menu bar styling) when all systems are online.
   - Show `visionpro.badge.exclamationmark` when any system is offline.
   - Show `visionpro.slash` if any check encounters an internal error.
5. **Interactive Dropdown Menu**:
   - Display the status of each system (Bluetooth, Wi-Fi, Keychain) individually in the dropdown menu.
   - Show details (e.g. Wi-Fi IP address) in the menu list.
   - Provide a "Check Now" button to trigger an immediate check.
   - Display the timestamp of the last check.
   - Provide a "Quit" button to terminate the accessory app.

## Architecture
- **App entry point**: `AVPMVDMenuBarApp.swift` initializes the application and sets the activation policy to `.accessory` so that the app runs without a Dock icon.
- **ViewModel**: `AVPMVDWatcher.swift` encapsulates running the native system calls, scheduling the dynamic timer, and managing the state.
- **Build System**: Swift Package Manager (`Package.swift`) to manage the compilation of the executable.
