# Design: Add Version Number to Menu

This document specifies the design for displaying a simple version number (e.g., "v1") within the dropdown menu.

## User Story
As a macOS user hosting Apple Vision Pro Mac Virtual Display sessions, I want to see the application's version in the menu bar dropdown so that I can easily verify which version of the utility is running.

## Backlog
- Define a static/constant version string (e.g. `private let appVersion = "v1"`) in `AVPMVDMenuBarApp.swift`.
- Display this version string inside the menu dropdown.

## Architecture
We will define a simple version identifier (`appVersion = "v1"`) directly in the source code to avoid complex semantic versioning or dynamic plist lookups.
We will place the version text item at the bottom of the menu dropdown, immediately above the "Quit" button.

## Requirements
- The version string must be styled as a simple version indicator (e.g., "Version: v1").
- The version must be clearly visible in the menu dropdown (above the "Quit" button).
- The version string is manually incremented in code when updates are made.
