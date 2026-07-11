# Onboarding

## Prerequisites
- macOS 14.0 or newer.
- Xcode 15+ (Swift 5.9+) or Xcode Command Line Tools.

## Installation / Building
1. Clone the repository.
2. Build the project in release mode:
   ```bash
   swift build -c release
   ```

## Running the Application
Run the compiled executable directly from your shell:
```bash
./.build/release/AVPMVDMenuBar &
```
The application will appear in your status bar. Click the Vision Pro icon to inspect the status. To close the application, click **Quit** in the menu.
