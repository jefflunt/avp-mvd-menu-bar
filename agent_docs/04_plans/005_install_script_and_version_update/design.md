# Design: Install Script and Version Update

This document specifies the design for updating the installation script, installation instructions in the README, and incrementing the version number of the application.

## User Story
As a developer and user of AVP MVD Watcher Menu Bar, I want a robust install script that packages, kills active instances, installs, and adds the application to Login Items cleanly. I also want the README updated to reflect this install method, and the build version bumped to 10 to trace the changes.

## Backlog
- Update the version string in `Sources/AVPMVDMenuBarApp.swift` from `"v9"` to `"v10"`.
- Update the README.md to instruct the user to run `./scripts/install.sh` for installation.
- Refactor `scripts/install.sh` to:
  - Unconditionally run `./scripts/package.sh` to package the app.
  - Kill any currently running version of `AVPMVDMenuBar`.
  - Install the packaged app into `/Applications`.
  - Start the app using `open`.
  - Add it to the Login Items via macOS `osascript`.

## Architecture
The scripts reside in `scripts/`. `install.sh` will call `package.sh` directly, kill any running instance by process name using `pkill`, copy the built `.app` bundle, run it, and add it to the user's Login Items.

## Requirements
- Installation instructions must point to `./scripts/install.sh` instead of manual background execution.
- Build/version number displayed in the dropdown menu must show `v10`.
- Previously running app instances must be terminated to avoid file-in-use issues during copy.
- The app must start automatically after installation and be configured as a Login Item.
