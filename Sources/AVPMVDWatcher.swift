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
    
    // Derived UI states
    @Published public var menuBarIcon: String = "visionpro"
    
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
    
    public init() {
        setupObservers()
        
        // Trigger initial check immediately
        Task {
            await runCheck()
        }
    }
    
    deinit {
        pathMonitor.cancel()
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
    }
    
    public func updateMenuBarIcon() {
        let allSystemsGo = isBluetoothOnline && isWifiOnline && isKeychainActive
        if allSystemsGo {
            menuBarIcon = "visionpro"
        } else {
            menuBarIcon = "visionpro.badge.exclamationmark"
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
