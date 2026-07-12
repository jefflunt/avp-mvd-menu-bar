# Step 1: Implement Version Number Display

## Tasks
1. Update `Sources/AVPMVDMenuBarApp.swift`:
   - Declare a private constant `appVersion = "v1"` on `AVPMVDMenuBarApp`.
   - Display this version string inside `MenuBarExtra` above the "Quit" button (e.g. `Text("Version: \(appVersion)")`).
2. Compile and package the application:
   - Run `scripts/package.sh` to package the updated binary.
