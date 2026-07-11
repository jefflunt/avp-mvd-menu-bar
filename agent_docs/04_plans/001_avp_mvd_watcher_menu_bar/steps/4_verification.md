# Step 4: Verification

Test and verify the application's correctness.

## Tasks
1. Build the project using `swift build` and resolve any compiler warnings/errors.
2. Verify that running the compiled executable correctly creates a menu bar icon.
3. Test dynamic update intervals by changing system state (e.g. toggling Bluetooth/Wi-Fi) or mocking exit codes and confirming:
   - 30-second polling when OK
   - 10-second polling when a system is down
4. Confirm proper teardown when clicking "Quit".
