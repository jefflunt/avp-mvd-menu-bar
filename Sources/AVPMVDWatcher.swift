import Foundation
import Combine
import IOBluetooth
import CoreWLAN
import Security
import CoreBluetooth
import Network
import AppKit

@MainActor
public class AVPMVDWatcher: ObservableObject {
    @Published public var lastCheckTime: Date? = nil
    @Published public var isChecking = false
    
    // Statuses
    @Published public var isBluetoothOnline = false
    @Published public var isWifiOnline = false
    @Published public var wifiIPAddress: String? = nil
    @Published public var isKeychainActive = false
    @Published public var isVisionProOnline = false
    @Published public var isMVDConnected = false
    @Published public var detectedVisionProName: String? = nil
    
    // Derived UI states
    @Published public var menuBarIcon: String = "visionpro.slash"
    
    public var lastCheckTimeString: String {
        guard let lastTime = lastCheckTime else { return "" }
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: lastTime)
    }
    
    // Observers and monitors
    private var bluetoothObserver: BluetoothObserver?
    private let pathMonitor = NWPathMonitor(requiredInterfaceType: .wifi)
    private var notificationObservers: [Any] = []
    private var airplayBrowser: NWBrowser?
    private var companionBrowser: NWBrowser?
    private var isVisionProOnlineViaAirPlay = false
    private var isVisionProOnlineViaCompanion = false
    
    public init() {
        setupObservers()
        
        // Trigger initial check immediately
        Task {
            await runCheck()
        }
    }
    
    deinit {
        pathMonitor.cancel()
        airplayBrowser?.cancel()
        companionBrowser?.cancel()
        for observer in notificationObservers {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
    }
    
    private func setupObservers() {
        // 1. Bluetooth Observer
        bluetoothObserver = BluetoothObserver { [weak self] isOnline in
            guard let self = self else { return }
            self.isBluetoothOnline = isOnline
            self.lastCheckTime = Date()
            self.updateMenuBarIcon()
        }
        
        // 2. Wi-Fi / IP Address Observer
        pathMonitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            let isPathSatisfied = path.status == .satisfied
            
            Task { @MainActor in
                let wifiInterfaceName = CWWiFiClient.shared().interface()?.interfaceName ?? "en0"
                let ip = isPathSatisfied ? Self.getIPAddress(for: wifiInterfaceName) : nil
                self.isWifiOnline = (ip != nil)
                self.wifiIPAddress = ip
                self.lastCheckTime = Date()
                self.updateMenuBarIcon()
            }
        }
        pathMonitor.start(queue: DispatchQueue.global(qos: .background))
        
        // 3. Keychain Availability Observers (screen lock/unlock notifications)
        let dnc = DistributedNotificationCenter.default()
        let o1 = dnc.addObserver(
            forName: NSNotification.Name("com.apple.screenIsUnlocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.isKeychainActive = Self.checkKeychainActive()
                self.lastCheckTime = Date()
                self.updateMenuBarIcon()
            }
        }
        notificationObservers.append(o1)
        
        let o2 = dnc.addObserver(
            forName: NSNotification.Name("com.apple.screenIsLocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.isKeychainActive = false
                self.lastCheckTime = Date()
                self.updateMenuBarIcon()
            }
        }
        notificationObservers.append(o2)
        
        // 4. Vision Pro Network Discovery Browsers
        setupVisionProBrowsers()
        
        // 5. Screen Parameters Observer (for MVD connection detection)
        let o3 = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.updateMVDConnectionStatus()
            }
        }
        notificationObservers.append(o3)
        
        updateMVDConnectionStatus()
    }
    
    private nonisolated func isAppleVisionPro(name: String, txtRecord: NWTXTRecord?) -> Bool {
        // 1. Check TXT record model if present (AirPlay)
        if let txt = txtRecord,
           let model = txt["model"],
           model.lowercased().contains("realitydevice") {
            return true
        }
        
        // 2. Check the service name (Companion Link)
        let lowerName = name.lowercased()
        
        // Skip if it's the host Mac itself
        let hostComputerName = Host.current().localizedName?.lowercased() ?? ""
        if !hostComputerName.isEmpty && lowerName == hostComputerName {
            return false
        }
        
        // Check for Vision Pro keywords
        let keywords = ["avp", "vision", "reality", "headset"]
        for keyword in keywords {
            if lowerName.contains(keyword) {
                return true
            }
        }
        
        return false
    }
    
    private func setupVisionProBrowsers() {
        // 1. AirPlay Browser
        let airplayDesc = NWBrowser.Descriptor.bonjour(type: "_airplay._tcp", domain: nil)
        let airplayParams = NWParameters()
        let apBrowser = NWBrowser(for: airplayDesc, using: airplayParams)
        self.airplayBrowser = apBrowser
        
        apBrowser.browseResultsChangedHandler = { [weak self] results, changes in
            guard let self = self else { return }
            var isDetected = false
            var detectedName: String? = nil
            for result in results {
                if case let .service(name, _, _, _) = result.endpoint {
                    var txtRecord: NWTXTRecord? = nil
                    if case let .bonjour(record) = result.metadata {
                        txtRecord = record
                    }
                    if self.isAppleVisionPro(name: name, txtRecord: txtRecord) {
                        isDetected = true
                        detectedName = name
                        break
                    }
                }
            }
            
            Task { @MainActor in
                self.updateVisionProStatus(viaAirPlay: isDetected, name: detectedName)
            }
        }
        apBrowser.start(queue: .main)
        
        // 2. Companion Link Browser
        let companionDesc = NWBrowser.Descriptor.bonjour(type: "_companion-link._tcp", domain: nil)
        let companionParams = NWParameters()
        let compBrowser = NWBrowser(for: companionDesc, using: companionParams)
        self.companionBrowser = compBrowser
        
        compBrowser.browseResultsChangedHandler = { [weak self] results, changes in
            guard let self = self else { return }
            var isDetected = false
            var detectedName: String? = nil
            for result in results {
                if case let .service(name, _, _, _) = result.endpoint {
                    var txtRecord: NWTXTRecord? = nil
                    if case let .bonjour(record) = result.metadata {
                        txtRecord = record
                    }
                    if self.isAppleVisionPro(name: name, txtRecord: txtRecord) {
                        isDetected = true
                        detectedName = name
                        break
                    }
                }
            }
            
            Task { @MainActor in
                self.updateVisionProStatus(viaCompanion: isDetected, name: detectedName)
            }
        }
        compBrowser.start(queue: .main)
    }
    
    private func updateVisionProStatus(viaAirPlay: Bool? = nil, viaCompanion: Bool? = nil, name: String? = nil) {
        if let viaAirPlay = viaAirPlay {
            isVisionProOnlineViaAirPlay = viaAirPlay
        }
        if let viaCompanion = viaCompanion {
            isVisionProOnlineViaCompanion = viaCompanion
        }
        if let name = name {
            self.detectedVisionProName = name
        } else if !isVisionProOnlineViaAirPlay && !isVisionProOnlineViaCompanion {
            self.detectedVisionProName = nil
        }
        
        let isOnline = isVisionProOnlineViaAirPlay || isVisionProOnlineViaCompanion
        if self.isVisionProOnline != isOnline {
            self.isVisionProOnline = isOnline
            self.lastCheckTime = Date()
            self.updateMenuBarIcon()
        }
    }
    
    private func restartVisionProBrowsers() {
        airplayBrowser?.cancel()
        companionBrowser?.cancel()
        setupVisionProBrowsers()
    }
    
    private func updateMVDConnectionStatus() {
        let isConnected = NSScreen.screens.contains { screen in
            let name = screen.localizedName.lowercased()
            return name.contains("mac virtual display") || name.contains("sidecar")
        }
        if self.isMVDConnected != isConnected {
            self.isMVDConnected = isConnected
            self.lastCheckTime = Date()
            self.updateMenuBarIcon()
        }
    }
    
    public func connectMVD() {
        // Check if Accessibility permissions are granted
        if !AXIsProcessTrusted() {
            let alert = NSAlert()
            alert.messageText = "Accessibility Permission Required"
            alert.informativeText = "To connect to your Apple Vision Pro directly, please grant Accessibility permissions to AVPMVDMenuBar in System Settings.\n\nAfter opening Settings, click the '+' button and add /Applications/AVPMVDMenuBar.app."
            alert.addButton(withTitle: "Open Settings")
            alert.addButton(withTitle: "Cancel")
            alert.alertStyle = .warning
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
            return
        }
        
        let deviceName = detectedVisionProName ?? "avp"
        
        let scriptSource = """
        tell application "System Events"
            tell process "ControlCenter"
                -- 1. Open Control Center
                try
                    click (first menu bar item of menu bar 1 whose description is "Control Center")
                on error
                    click menu bar item 1 of menu bar 1
                end try
                delay 0.5
                
                -- 2. Click the Screen Mirroring button by AXIdentifier
                tell window 1
                    try
                        set mirroringBtn to first checkbox of group 1 whose value of attribute "AXIdentifier" is "controlcenter-screen-mirroring"
                        click mirroringBtn
                    on error
                        error "Could not find controlcenter-screen-mirroring checkbox"
                    end try
                end tell
                delay 1.0
                
                -- 3. Click the target device in the list (preferring Sidecar/MVD)
                tell window 1
                    tell group 1
                        tell scroll area 1
                            tell group 1
                                set targetName to "\(deviceName)"
                                set allCheckboxes to checkboxes
                                set chosenBtn to missing value
                                
                                -- Pass 1: Try to find a Sidecar checkbox matching deviceName
                                repeat with cb in allCheckboxes
                                    try
                                        set cbId to value of attribute "AXIdentifier" of cb
                                        set cbTitle to title of cb
                                        set cbName to name of cb
                                        if cbId starts with "screen-mirroring-device-Sidecar" then
                                            if cbId contains targetName or cbTitle contains targetName or cbName contains targetName then
                                                set chosenBtn to cb
                                                exit repeat
                                            end if
                                        end if
                                    catch
                                    end try
                                end repeat
                                
                                -- Pass 2: Try to find any Sidecar checkbox containing AVP keywords
                                if chosenBtn is missing value then
                                    set keywords to {"avp", "vision", "reality", "headset"}
                                    repeat with kw in keywords
                                        if chosenBtn is missing value then
                                            repeat with cb in allCheckboxes
                                                try
                                                    set cbId to value of attribute "AXIdentifier" of cb
                                                    set cbTitle to title of cb
                                                    set cbName to name of cb
                                                    if cbId starts with "screen-mirroring-device-Sidecar" then
                                                        if cbId contains kw or cbTitle contains kw or cbName contains kw then
                                                            set chosenBtn to cb
                                                            exit repeat
                                                        end if
                                                    end if
                                                catch
                                                end try
                                            end repeat
                                        end if
                                    end repeat
                                end if
                                
                                -- Pass 3: Try to find an AirPlay checkbox matching deviceName
                                if chosenBtn is missing value then
                                    repeat with cb in allCheckboxes
                                        try
                                            set cbId to value of attribute "AXIdentifier" of cb
                                            set cbTitle to title of cb
                                            set cbName to name of cb
                                            if cbId starts with "screen-mirroring-device-AirPlay" then
                                                if cbId contains targetName or cbTitle contains targetName or cbName contains targetName then
                                                    set chosenBtn to cb
                                                    exit repeat
                                                end if
                                            end if
                                        catch
                                        end try
                                    end repeat
                                end if
                                
                                -- Pass 4: Fallback to the first checkbox starting with screen-mirroring-device-Sidecar
                                if chosenBtn is missing value then
                                    repeat with cb in allCheckboxes
                                        try
                                            set cbId to value of attribute "AXIdentifier" of cb
                                            if cbId starts with "screen-mirroring-device-Sidecar" then
                                                set chosenBtn to cb
                                                exit repeat
                                            end if
                                        catch
                                        end try
                                    end repeat
                                end if
                                
                                -- Pass 5: Ultimate fallback to checkbox 1
                                if chosenBtn is missing value then
                                    if (count of allCheckboxes) > 0 then
                                        set chosenBtn to item 1 of allCheckboxes
                                    end if
                                end if
                                
                                -- Click the chosen button
                                if chosenBtn is not missing value then
                                    click chosenBtn
                                else
                                    error "Could not find any screen mirroring devices"
                                end if
                            end tell
                        end tell
                    end tell
                end tell
            end tell
        end tell
        """
        
        let appleScript = NSAppleScript(source: scriptSource)
        var error: NSDictionary?
        appleScript?.executeAndReturnError(&error)
        if let error = error {
            print("AppleScript execution failed: \(error)")
            // Fallback: Open Display Settings pane if script fails completely
            if let url = URL(string: "x-apple.systempreferences:com.apple.Displays-Settings.extension") {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    public func updateMenuBarIcon() {
        let localReady = isBluetoothOnline && isWifiOnline && isKeychainActive
        if !localReady {
            menuBarIcon = "visionpro.badge.exclamationmark"
        } else if isVisionProOnline {
            menuBarIcon = "visionpro"
        } else {
            menuBarIcon = "visionpro.slash"
        }
    }
    
    public func runCheck() async {
        guard !isChecking else { return }
        isChecking = true
        
        let results = await Task.detached(priority: .userInitiated) { () -> (Bool, Bool, String?, Bool) in
            // 1. Bluetooth check (Native)
            let btOnline = (IOBluetoothHostController.default()?.powerState == kBluetoothHCIPowerStateON)
            
            // 2. Wi-Fi check (Native)
            let wifiInterfaceName = CWWiFiClient.shared().interface()?.interfaceName ?? "en0"
            let ip = AVPMVDWatcher.getIPAddress(for: wifiInterfaceName)
            let wifiOnline = (ip != nil)
            
            // 3. Keychain check (Native)
            let keychainActive = AVPMVDWatcher.checkKeychainActive()
            
            return (btOnline, wifiOnline, ip, keychainActive)
        }.value
        
        self.isBluetoothOnline = results.0
        self.isWifiOnline = results.1
        self.wifiIPAddress = results.2
        self.isKeychainActive = results.3
        self.lastCheckTime = Date()
        self.isChecking = false
        
        self.updateMVDConnectionStatus()
        self.restartVisionProBrowsers()
        self.updateMenuBarIcon()
    }
    
    // Helpers (Marked nonisolated so they can run safely in Task.detached)
    private nonisolated static func getIPAddress(for interfaceName: String) -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        guard let firstAddr = ifaddr else { return nil }
        
        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let addr = ptr.pointee.ifa_addr.pointee
            if addr.sa_family == UInt8(AF_INET) {
                let name = String(cString: ptr.pointee.ifa_name)
                if name == interfaceName {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    var mutableAddr = addr
                    if getnameinfo(&mutableAddr, socklen_t(addr.sa_len), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 {
                        address = String(cString: hostname)
                    }
                }
            }
        }
        freeifaddrs(ifaddr)
        return address
    }
    
    private nonisolated static func checkKeychainActive() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "AVPMVDMenuBarTestService",
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}

@MainActor
private class BluetoothObserver: NSObject, CBCentralManagerDelegate {
    private var centralManager: CBCentralManager?
    private let onStateChanged: @Sendable @MainActor (Bool) -> Void
    
    init(onStateChanged: @escaping @Sendable @MainActor (Bool) -> Void) {
        self.onStateChanged = onStateChanged
        super.init()
        self.centralManager = CBCentralManager(delegate: self, queue: .main)
    }
    
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            let isOnline = central.state == .poweredOn
            onStateChanged(isOnline)
        }
    }
}
