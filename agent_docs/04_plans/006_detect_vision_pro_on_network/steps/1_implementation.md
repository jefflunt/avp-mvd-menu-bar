# Step 1: Implementation of Vision Pro Network Detection

## Tasks
1. Update `scripts/package.sh` to include `NSLocalNetworkUsageDescription` and `NSBonjourServices` keys (with both `_airplay._tcp` and `_companion-link._tcp` service types) in the dynamically generated `Info.plist`.
2. Add `@Published public var isVisionProOnline = false` to `AVPMVDWatcher` in `Sources/AVPMVDWatcher.swift`.
3. Implement `setupVisionProBrowsers()` in `AVPMVDWatcher.swift` using two `NWBrowser` instances to monitor `_airplay._tcp` and `_companion-link._tcp` Bonjour service changes.
4. Implement `isAppleVisionPro(name:txtRecord:)` function filtering results based on:
   - Metadata `txtRecord["model"]` containing the substring `"RealityDevice"`.
   - Name containing keywords (`avp`, `vision`, `reality`, `headset`) while not matching `Host.current().localizedName` (to ignore the host Mac).
5. Start both browsers on `DispatchQueue.main` to safely update state.
6. Update `runCheck()` to cancel and restart both browsers to force a fresh network query.
7. Update `updateMenuBarIcon()` to use the three-state logic.
8. Add a new row to `AVPMVDMenuBarApp.swift` to display "Vision Pro: Detected" (Green) or "Vision Pro: Not Detected" (Gray) based on `isVisionProOnline`.
