import SwiftUI
import AppKit
import AVPMVDCore

@main
struct AVPMVDMenuBarApp: App {
    @StateObject private var watcher = AVPMVDWatcher()
    private let appVersion = "v12"
    
    init() {
        // Dynamically hide Dock icon and run only in the menu bar
        NSApplication.shared.setActivationPolicy(.accessory)
    }
    
    var body: some Scene {
        MenuBarExtra {
            Text("Mac Virtual Display Readiness")
            
            Divider()
            
            // Bluetooth Status Item
            if watcher.isBluetoothOnline {
                Text("\(Text(Image(systemName: "circle.fill")).foregroundColor(.green)) Bluetooth: Online")
            } else {
                Text("\(Text(Image(systemName: "circle.fill")).foregroundColor(.red)) Bluetooth: Offline/Starting")
            }
            
            // Wi-Fi Status Item
            if watcher.isWifiOnline {
                Text("\(Text(Image(systemName: "circle.fill")).foregroundColor(.green)) Wi-Fi: Online (\(watcher.wifiIPAddress ?? "Unknown IP"))")
            } else {
                Text("\(Text(Image(systemName: "circle.fill")).foregroundColor(.red)) Wi-Fi: No IP Address")
            }
            
            // Keychain Status Item
            if watcher.isKeychainActive {
                Text("\(Text(Image(systemName: "circle.fill")).foregroundColor(.green)) Keychain: Active")
            } else {
                Text("\(Text(Image(systemName: "circle.fill")).foregroundColor(.red)) Keychain: Starting")
            }
            
            // Vision Pro Status Item
            if watcher.isMVDConnected {
                Button {
                    watcher.disconnectMVD()
                } label: {
                    Text("\(Text(Image(systemName: "circle.fill")).foregroundColor(.green)) Vision Pro: Connected (MVD) (Click to Disconnect)")
                }
            } else if watcher.isVisionProOnline {
                Button {
                    watcher.connectMVD()
                } label: {
                    Text("\(Text(Image(systemName: "circle.fill")).foregroundColor(.blue)) Vision Pro: Detected (Click to Connect)")
                }
                .keyboardShortcut("c", modifiers: [.command, .option])
            } else {
                Text("\(Text(Image(systemName: "circle.fill")).foregroundColor(.gray)) Vision Pro: Not Detected")
            }
            
            Divider()
            
            // Last checked time
            if !watcher.lastCheckTimeString.isEmpty {
                Text("Last Checked: \(watcher.lastCheckTimeString)")
            }
            
            Button(watcher.isChecking ? "Checking..." : "Check Now") {
                Task {
                    await watcher.runCheck()
                }
            }
            .disabled(watcher.isChecking)
            
            Divider()
            
            Text(appVersion)
            
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
            
        } label: {
            Image(systemName: watcher.menuBarIcon)
        }
    }
}
