import Foundation
import Combine
import IOBluetooth
import CoreWLAN
import Security
import CoreBluetooth
import Network
import AppKit
import Carbon

// MARK: - Protocols for Testability

@MainActor
public protocol BluetoothMonitor: AnyObject {
    var isBluetoothOnline: Bool { get }
    func checkPowerState() async -> Bool
    func start(onStateChanged: @escaping @Sendable @MainActor (Bool) -> Void)
}

@MainActor
public protocol WifiMonitor: AnyObject {
    var isWifiOnline: Bool { get }
    var wifiIPAddress: String? { get }
    func checkWifiStatus() async -> (Bool, String?)
    func start(onUpdate: @escaping @Sendable @MainActor (Bool, String?) -> Void)
}

@MainActor
public protocol KeychainMonitor: AnyObject {
    var isKeychainActive: Bool { get }
    func checkKeychainActive() async -> Bool
    func start(onUpdate: @escaping @Sendable @MainActor (Bool) -> Void)
}

@MainActor
public protocol ScreenMonitor: AnyObject {
    var isMVDConnected: Bool { get }
    func start(onUpdate: @escaping @Sendable @MainActor (Bool) -> Void)
}

@MainActor
public protocol BonjourBrowser: AnyObject {
    func start(onUpdate: @escaping @Sendable @MainActor (Bool, String?) -> Void)
    func restart()
    func cancel()
}

@MainActor
public protocol ScriptExecutor: AnyObject {
    var isProcessTrusted: Bool { get }
    func executeScript(_ source: String) -> NSDictionary?
}

// MARK: - Production Implementations

@MainActor
public class RealBluetoothMonitor: NSObject, BluetoothMonitor, CBCentralManagerDelegate {
    private var centralManager: CBCentralManager?
    private var onStateChanged: (@Sendable @MainActor (Bool) -> Void)?
    
    public override init() {
        super.init()
    }
    
    public var isBluetoothOnline: Bool {
        IOBluetoothHostController.default()?.powerState == kBluetoothHCIPowerStateON
    }
    
    public func checkPowerState() async -> Bool {
        await Task.detached(priority: .userInitiated) {
            IOBluetoothHostController.default()?.powerState == kBluetoothHCIPowerStateON
        }.value
    }
    
    public func start(onStateChanged: @escaping @Sendable @MainActor (Bool) -> Void) {
        self.onStateChanged = onStateChanged
        self.centralManager = CBCentralManager(delegate: self, queue: .main)
    }
    
    nonisolated public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            let isOnline = central.state == .poweredOn
            self.onStateChanged?(isOnline)
        }
    }
}

@MainActor
public class RealWifiMonitor: WifiMonitor {
    private let pathMonitor = NWPathMonitor(requiredInterfaceType: .wifi)
    private var onUpdate: (@Sendable @MainActor (Bool, String?) -> Void)?
    
    public var isWifiOnline: Bool {
        let wifiInterfaceName = CWWiFiClient.shared().interface()?.interfaceName ?? "en0"
        let ip = RealWifiMonitor.getIPAddress(for: wifiInterfaceName)
        return ip != nil
    }
    
    public var wifiIPAddress: String? {
        let wifiInterfaceName = CWWiFiClient.shared().interface()?.interfaceName ?? "en0"
        return RealWifiMonitor.getIPAddress(for: wifiInterfaceName)
    }
    
    public init() {}
    
    public func checkWifiStatus() async -> (Bool, String?) {
        await Task.detached(priority: .userInitiated) {
            let wifiInterfaceName = CWWiFiClient.shared().interface()?.interfaceName ?? "en0"
            let ip = RealWifiMonitor.getIPAddress(for: wifiInterfaceName)
            return (ip != nil, ip)
        }.value
    }
    
    public func start(onUpdate: @escaping @Sendable @MainActor (Bool, String?) -> Void) {
        self.onUpdate = onUpdate
        pathMonitor.pathUpdateHandler = { path in
            let isPathSatisfied = path.status == .satisfied
            let wifiInterfaceName = CWWiFiClient.shared().interface()?.interfaceName ?? "en0"
            let ip = isPathSatisfied ? RealWifiMonitor.getIPAddress(for: wifiInterfaceName) : nil
            
            Task { @MainActor in
                onUpdate(ip != nil, ip)
            }
        }
        pathMonitor.start(queue: DispatchQueue.global(qos: .background))
    }
    
    deinit {
        pathMonitor.cancel()
    }
    
    nonisolated public static func getIPAddress(for interfaceName: String) -> String? {
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
}

@MainActor
public class RealKeychainMonitor: KeychainMonitor {
    private var notificationObservers: [Any] = []
    private var onUpdate: (@Sendable @MainActor (Bool) -> Void)?
    
    public init() {}
    
    public var isKeychainActive: Bool {
        RealKeychainMonitor.checkKeychainActive()
    }
    
    public func checkKeychainActive() async -> Bool {
        await Task.detached(priority: .userInitiated) {
            RealKeychainMonitor.checkKeychainActive()
        }.value
    }
    
    public func start(onUpdate: @escaping @Sendable @MainActor (Bool) -> Void) {
        self.onUpdate = onUpdate
        
        let dnc = DistributedNotificationCenter.default()
        let o1 = dnc.addObserver(
            forName: NSNotification.Name("com.apple.screenIsUnlocked"),
            object: nil,
            queue: .main
        ) { _ in
            let isActive = RealKeychainMonitor.checkKeychainActive()
            Task { @MainActor in
                onUpdate(isActive)
            }
        }
        notificationObservers.append(o1)
        
        let o2 = dnc.addObserver(
            forName: NSNotification.Name("com.apple.screenIsLocked"),
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                onUpdate(false)
            }
        }
        notificationObservers.append(o2)
    }
    
    deinit {
        for observer in notificationObservers {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
    }
    
    nonisolated public static func checkKeychainActive() -> Bool {
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
public class RealScreenMonitor: ScreenMonitor {
    private var observer: Any?
    
    public init() {}
    
    public var isMVDConnected: Bool {
        NSScreen.screens.contains { screen in
            let name = screen.localizedName.lowercased()
            return name.contains("mac virtual display") || name.contains("sidecar")
        }
    }
    
    public func start(onUpdate: @escaping @Sendable @MainActor (Bool) -> Void) {
        self.observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                let connected = self.isMVDConnected
                onUpdate(connected)
            }
        }
    }
    
    deinit {
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

@MainActor
public class RealBonjourBrowser: BonjourBrowser {
    private var airplayBrowser: NWBrowser?
    private var companionBrowser: NWBrowser?
    private var isVisionProOnlineViaAirPlay = false
    private var isVisionProOnlineViaCompanion = false
    private var detectedVisionProName: String?
    private var onUpdate: (@Sendable @MainActor (Bool, String?) -> Void)?
    
    public init() {}
    
    public func start(onUpdate: @escaping @Sendable @MainActor (Bool, String?) -> Void) {
        self.onUpdate = onUpdate
        setupVisionProBrowsers()
    }
    
    public func restart() {
        airplayBrowser?.cancel()
        companionBrowser?.cancel()
        setupVisionProBrowsers()
    }
    
    public func cancel() {
        airplayBrowser?.cancel()
        companionBrowser?.cancel()
    }
    
    deinit {
        let airplay = airplayBrowser
        let companion = companionBrowser
        airplay?.cancel()
        companion?.cancel()
    }
    
    private func setupVisionProBrowsers() {
        let airplayDesc = NWBrowser.Descriptor.bonjour(type: "_airplay._tcp", domain: nil)
        let airplayParams = NWParameters()
        let apBrowser = NWBrowser(for: airplayDesc, using: airplayParams)
        self.airplayBrowser = apBrowser
        
        apBrowser.browseResultsChangedHandler = { [weak self] results, changes in
            Task { @MainActor in
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
                self.updateVisionProStatus(viaAirPlay: isDetected, name: detectedName)
            }
        }
        apBrowser.start(queue: .main)
        
        let companionDesc = NWBrowser.Descriptor.bonjour(type: "_companion-link._tcp", domain: nil)
        let companionParams = NWParameters()
        let compBrowser = NWBrowser(for: companionDesc, using: companionParams)
        self.companionBrowser = compBrowser
        
        compBrowser.browseResultsChangedHandler = { [weak self] results, changes in
            Task { @MainActor in
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
        if let onUpdate = onUpdate {
            let name = self.detectedVisionProName
            onUpdate(isOnline, name)
        }
    }
    
    private func isAppleVisionPro(name: String, txtRecord: NWTXTRecord?) -> Bool {
        if let txt = txtRecord,
           let model = txt["model"],
           model.lowercased().contains("realitydevice") {
            return true
        }
        
        let lowerName = name.lowercased()
        let hostComputerName = Host.current().localizedName?.lowercased() ?? ""
        if !hostComputerName.isEmpty && lowerName == hostComputerName {
            return false
        }
        
        let keywords = ["avp", "vision", "reality", "headset"]
        for keyword in keywords {
            if lowerName.contains(keyword) {
                return true
            }
        }
        return false
    }
}

@MainActor
public class RealScriptExecutor: ScriptExecutor {
    public init() {}
    
    public var isProcessTrusted: Bool {
        AXIsProcessTrusted()
    }
    
    public func executeScript(_ source: String) -> NSDictionary? {
        let appleScript = NSAppleScript(source: source)
        var error: NSDictionary?
        appleScript?.executeAndReturnError(&error)
        return error
    }
}

// MARK: - Global Hotkey Manager

@MainActor
public class GlobalHotKeyManager {
    public static let shared = GlobalHotKeyManager()
    
    private var connectHotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var onConnectPressed: (() -> Void)?
    
    private init() {}
    
    private static func makeOSType(_ string: String) -> OSType {
        var result: UInt32 = 0
        for char in string.utf8.prefix(4) {
            result = (result << 8) + UInt32(char)
        }
        return result
    }
    
    public func registerConnectHotKey(onConnect: @escaping () -> Void) {
        // Bypass registering keyboard handlers if running in a test suite
        if NSClassFromString("XCTestCase") != nil {
            return
        }
        
        self.onConnectPressed = onConnect
        
        // 1. Install Event Handler
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        let handlerProc: EventHandlerProcPtr = { nextHandler, event, userData in
            guard let event = event else { return OSStatus(eventNotHandledErr) }
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            
            if status == noErr {
                let id = hotKeyID.id
                Task { @MainActor in
                    GlobalHotKeyManager.shared.triggerHotKey(id: id)
                }
                return noErr
            }
            return OSStatus(eventNotHandledErr)
        }
        
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            handlerProc,
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )
        
        if installStatus != noErr {
            print("Failed to install global hotkey event handler: \(installStatus)")
            return
        }
        
        // 2. Register Connect Hotkey: Option + Command + C
        // Key code for 'C' is 8
        // Modifiers: cmdKey (256) | optionKey (2048) = 2304
        let signature = Self.makeOSType("AVPc")
        let connectID = EventHotKeyID(signature: signature, id: 1)
        let connectStatus = RegisterEventHotKey(
            UInt32(8),
            UInt32(2304),
            connectID,
            GetApplicationEventTarget(),
            0,
            &connectHotKeyRef
        )
        if connectStatus != noErr {
            print("Failed to register Connect global hotkey: \(connectStatus)")
        }
    }
    
    private func triggerHotKey(id: UInt32) {
        if id == 1 {
            onConnectPressed?()
        }
    }
    
    deinit {
        if let ref = connectHotKeyRef {
            UnregisterEventHotKey(ref)
        }
        if let ref = eventHandlerRef {
            RemoveEventHandler(ref)
        }
    }
}

// MARK: - Core Watcher

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
    
    private let bluetoothMonitor: any BluetoothMonitor
    private let wifiMonitor: any WifiMonitor
    private let keychainMonitor: any KeychainMonitor
    private let screenMonitor: any ScreenMonitor
    private let bonjourBrowser: any BonjourBrowser
    private let scriptExecutor: any ScriptExecutor
    
    public convenience init() {
        self.init(
            bluetoothMonitor: RealBluetoothMonitor(),
            wifiMonitor: RealWifiMonitor(),
            keychainMonitor: RealKeychainMonitor(),
            screenMonitor: RealScreenMonitor(),
            bonjourBrowser: RealBonjourBrowser(),
            scriptExecutor: RealScriptExecutor()
        )
    }
    
    public init(
        bluetoothMonitor: any BluetoothMonitor,
        wifiMonitor: any WifiMonitor,
        keychainMonitor: any KeychainMonitor,
        screenMonitor: any ScreenMonitor,
        bonjourBrowser: any BonjourBrowser,
        scriptExecutor: any ScriptExecutor
    ) {
        self.bluetoothMonitor = bluetoothMonitor
        self.wifiMonitor = wifiMonitor
        self.keychainMonitor = keychainMonitor
        self.screenMonitor = screenMonitor
        self.bonjourBrowser = bonjourBrowser
        self.scriptExecutor = scriptExecutor
        
        setupObservers()
        
        // Register global connect hotkey
        GlobalHotKeyManager.shared.registerConnectHotKey { [weak self] in
            guard let self = self else { return }
            // Only works when detected but not yet connected
            if self.isVisionProOnline && !self.isMVDConnected {
                self.connectMVD()
            }
        }
        
        // Trigger initial check immediately
        Task {
            await runCheck()
        }
    }
    
    deinit {
        let browser = bonjourBrowser
        Task { @MainActor in
            browser.cancel()
        }
    }
    
    private func setupObservers() {
        bluetoothMonitor.start { [weak self] isOnline in
            guard let self = self else { return }
            self.isBluetoothOnline = isOnline
            self.lastCheckTime = Date()
            self.updateMenuBarIcon()
        }
        
        wifiMonitor.start { [weak self] isOnline, ipAddress in
            guard let self = self else { return }
            self.isWifiOnline = isOnline
            self.wifiIPAddress = ipAddress
            self.lastCheckTime = Date()
            self.updateMenuBarIcon()
        }
        
        keychainMonitor.start { [weak self] isActive in
            guard let self = self else { return }
            self.isKeychainActive = isActive
            self.lastCheckTime = Date()
            self.updateMenuBarIcon()
        }
        
        bonjourBrowser.start { [weak self] isOnline, name in
            guard let self = self else { return }
            self.isVisionProOnline = isOnline
            self.detectedVisionProName = name
            self.lastCheckTime = Date()
            self.updateMenuBarIcon()
        }
        
        screenMonitor.start { [weak self] isConnected in
            guard let self = self else { return }
            self.isMVDConnected = isConnected
            self.lastCheckTime = Date()
            self.updateMenuBarIcon()
        }
        
        // Sync initial state
        self.isBluetoothOnline = bluetoothMonitor.isBluetoothOnline
        self.isWifiOnline = wifiMonitor.isWifiOnline
        self.wifiIPAddress = wifiMonitor.wifiIPAddress
        self.isKeychainActive = keychainMonitor.isKeychainActive
        self.isMVDConnected = screenMonitor.isMVDConnected
        
        updateMenuBarIcon()
    }
    
    public func connectMVD() {
        if !scriptExecutor.isProcessTrusted {
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
        
        let error = scriptExecutor.executeScript(scriptSource)
        if let error = error {
            print("AppleScript execution failed: \(error)")
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
        
        let bt = await bluetoothMonitor.checkPowerState()
        let (wifi, ip) = await wifiMonitor.checkWifiStatus()
        let kc = await keychainMonitor.checkKeychainActive()
        
        self.isBluetoothOnline = bt
        self.isWifiOnline = wifi
        self.wifiIPAddress = ip
        self.isKeychainActive = kc
        self.isMVDConnected = screenMonitor.isMVDConnected
        self.lastCheckTime = Date()
        self.isChecking = false
        
        bonjourBrowser.restart()
        updateMenuBarIcon()
    }
}
