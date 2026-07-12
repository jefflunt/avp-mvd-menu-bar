# Design: Update MVD Readiness Text

This document specifies the design for updating the main menu header text to clarify that it displays "Readiness" rather than active "Status", and updating the README screenshot accordingly.

## User Story
As a macOS user hosting Apple Vision Pro Mac Virtual Display (MVD) sessions, I want the menu bar app to label its main section "Mac Virtual Display Readiness" rather than "Mac Virtual Display Status" so that I understand it measures if the Mac is ready to connect, not whether an active connection exists.

## Backlog
- Update the main menu header label in `AVPMVDMenuBarApp.swift` from "Mac Virtual Display Status" to "Mac Virtual Display Readiness".
- The user will manually capture a new screenshot of the dropdown menu and replace the existing screenshot at `images/avp-mvd-screenshot.png`. We will provide a reminder/instructions for this in the walkthrough.

## Architecture
The text update is a simple label change in `AVPMVDMenuBarApp.swift`'s body.
Updating the screenshot requires building the app, running it, opening the menu bar dropdown, and capturing the dropdown using the macOS `screencapture` utility.

## Requirements
- Label updated exactly to "Mac Virtual Display Readiness".
- Screenshot `images/avp-mvd-screenshot.png` updated to show the new label.
- App continues to compile and run successfully.
