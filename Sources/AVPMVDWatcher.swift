import Foundation
import Combine
import IOBluetooth
import CoreWLAN
import Security

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
    
    private var timer: Timer? = nil
    private var currentInterval: TimeInterval = 30.0
    
    public var lastCheckTimeString: String {
        guard let lastTime = lastCheckTime else { return "" }
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: lastTime)
    }
    
    public init() {
        startTimer()
        // Trigger initial check immediately
        Task {
            await runCheck()
        }
    }
    
    deinit {
        timer?.invalidate()
    }
    
    public func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: currentInterval, repeats: true) { [weak self] _ in
            Task {
                await self?.runCheck()
            }
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
        
        // Determine icon based on status
        let allSystemsGo = self.isBluetoothOnline && self.isWifiOnline && self.isKeychainActive
        if allSystemsGo {
            self.menuBarIcon = "visionpro"
        } else {
            self.menuBarIcon = "visionpro.badge.exclamationmark"
        }
        
        // Adjust polling interval dynamically based on health status
        let newInterval: TimeInterval = allSystemsGo ? 30.0 : 10.0
        if newInterval != currentInterval {
            currentInterval = newInterval
            startTimer()
        }
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
