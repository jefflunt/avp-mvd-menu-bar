# Step 2: Verification

## Tasks
1. Run `./scripts/install.sh`.
2. Verify the application runs, is located in `/Applications`, and the version displayed in the menu bar dropdown is `v10`.
3. Verify that the application was added to system Login Items:
   - Check using `osascript -e 'tell application "System Events" to get name of every login item'` to ensure "AVPMVDMenuBar" is listed.
4. Run the install script again while the app is active and confirm that the running process is terminated, the app is repackaged, and restarted.
