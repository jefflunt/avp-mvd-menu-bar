# Step 2: Verification of Keyboard Shortcuts, Disconnect, and Unit Test Backfill

## Tasks
1. Run `swift test` (unsandboxed if necessary) to execute all unit tests and verify they pass.
2. Run `swift build -c release` to verify error-free compilation of both core library and executable.
3. Build and sign the application package using `./scripts/package.sh`.
4. Open the packaged menu bar application.
5. Manually verify the behavior under the following states:
   - **AVP Not Detected**: Neither shortcut (⌥⌘C nor ⌥⌘D) should be active or triggered (even with the dropdown closed).
   - **AVP Detected, Not Connected**: Pressing `⌥⌘C` (with the dropdown closed) should trigger the connection script (`connectMVD`). `⌥⌘D` should not do anything.
   - **AVP Connected**: Pressing `⌥⌘D` (with the dropdown closed) should trigger the disconnection script (`disconnectMVD`). `⌥⌘C` should not do anything.
