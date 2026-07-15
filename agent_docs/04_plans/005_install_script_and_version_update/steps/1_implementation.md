# Step 1: Implementation of Install Script and Version Updates

## Tasks
1. Update `Sources/AVPMVDMenuBarApp.swift`:
   - Change `appVersion` private constant value from `"v9"` to `"v10"`.
2. Update `README.md`:
   - Update Compilation & Usage section to instruct the user to run `./scripts/install.sh`.
3. Update `scripts/install.sh`:
   - Unconditionally execute `./scripts/package.sh`.
   - Use `pkill -x "AVPMVDMenuBar" || true` to kill any running instance of the application.
   - Clean up installation step to ensure copy, start (`open /Applications/AVPMVDMenuBar.app`), and adding to Login Items occur in the expected sequence.
