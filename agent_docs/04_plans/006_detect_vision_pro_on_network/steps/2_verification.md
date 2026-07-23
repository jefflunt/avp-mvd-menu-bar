# Step 2: Verification of Vision Pro Network Detection

## Tasks
1. Compile the project with `swift build` to verify there are no compilation errors or warnings.
2. Build and sign the application package with `./scripts/package.sh`.
3. Check that the generated `Info.plist` at `.build/release/AVPMVDMenuBar.app/Contents/Info.plist` correctly contains:
   - `NSLocalNetworkUsageDescription`
   - `NSBonjourServices` declaring `_airplay._tcp`
4. Run the application and confirm the dropdown displays the new check.
