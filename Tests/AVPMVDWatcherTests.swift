import XCTest
import Combine
@testable import AVPMVDCore

// MARK: - Mocks

final class MockBluetoothMonitor: BluetoothMonitor {
    var isBluetoothOnline: Bool = false
    var onStateChanged: (@Sendable @MainActor (Bool) -> Void)?
    
    func checkPowerState() async -> Bool {
        return isBluetoothOnline
    }
    
    func start(onStateChanged: @escaping @Sendable @MainActor (Bool) -> Void) {
        self.onStateChanged = onStateChanged
    }
    
    func triggerUpdate(_ isOnline: Bool) async {
        await MainActor.run {
            self.isBluetoothOnline = isOnline
            self.onStateChanged?(isOnline)
        }
    }
}

final class MockWifiMonitor: WifiMonitor {
    var isWifiOnline: Bool = false
    var wifiIPAddress: String? = nil
    var onUpdate: (@Sendable @MainActor (Bool, String?) -> Void)?
    
    func checkWifiStatus() async -> (Bool, String?) {
        return (isWifiOnline, wifiIPAddress)
    }
    
    func start(onUpdate: @escaping @Sendable @MainActor (Bool, String?) -> Void) {
        self.onUpdate = onUpdate
    }
    
    func triggerUpdate(_ isOnline: Bool, ip: String?) async {
        await MainActor.run {
            self.isWifiOnline = isOnline
            self.wifiIPAddress = ip
            self.onUpdate?(isOnline, ip)
        }
    }
}

final class MockKeychainMonitor: KeychainMonitor {
    var isKeychainActive: Bool = false
    var onUpdate: (@Sendable @MainActor (Bool) -> Void)?
    
    func checkKeychainActive() async -> Bool {
        return isKeychainActive
    }
    
    func start(onUpdate: @escaping @Sendable @MainActor (Bool) -> Void) {
        self.onUpdate = onUpdate
    }
    
    func triggerUpdate(_ isActive: Bool) async {
        await MainActor.run {
            self.isKeychainActive = isActive
            self.onUpdate?(isActive)
        }
    }
}

final class MockScreenMonitor: ScreenMonitor {
    var isMVDConnected: Bool = false
    var onUpdate: (@Sendable @MainActor (Bool) -> Void)?
    
    func start(onUpdate: @escaping @Sendable @MainActor (Bool) -> Void) {
        self.onUpdate = onUpdate
    }
    
    func triggerUpdate(_ isConnected: Bool) async {
        await MainActor.run {
            self.isMVDConnected = isConnected
            self.onUpdate?(isConnected)
        }
    }
}

final class MockBonjourBrowser: BonjourBrowser {
    var restartCount = 0
    var cancelCount = 0
    var onUpdate: (@Sendable @MainActor (Bool, String?) -> Void)?
    
    func start(onUpdate: @escaping @Sendable @MainActor (Bool, String?) -> Void) {
        self.onUpdate = onUpdate
    }
    
    func restart() {
        restartCount += 1
    }
    
    func cancel() {
        cancelCount += 1
    }
    
    func triggerUpdate(_ isOnline: Bool, name: String?) async {
        await MainActor.run {
            self.onUpdate?(isOnline, name)
        }
    }
}

final class MockScriptExecutor: ScriptExecutor {
    var isProcessTrusted: Bool = true
    var executedScripts: [String] = []
    var errorToReturn: NSDictionary? = nil
    
    func executeScript(_ source: String) -> NSDictionary? {
        executedScripts.append(source)
        return errorToReturn
    }
}

// MARK: - Tests

@MainActor
final class AVPMVDWatcherTests: XCTestCase {
    
    private var bluetoothMonitor: MockBluetoothMonitor!
    private var wifiMonitor: MockWifiMonitor!
    private var keychainMonitor: MockKeychainMonitor!
    private var screenMonitor: MockScreenMonitor!
    private var bonjourBrowser: MockBonjourBrowser!
    private var scriptExecutor: MockScriptExecutor!
    private var watcher: AVPMVDWatcher!
    
    override func setUp() async throws {
        try await super.setUp()
        bluetoothMonitor = MockBluetoothMonitor()
        wifiMonitor = MockWifiMonitor()
        keychainMonitor = MockKeychainMonitor()
        screenMonitor = MockScreenMonitor()
        bonjourBrowser = MockBonjourBrowser()
        scriptExecutor = MockScriptExecutor()
        
        watcher = AVPMVDWatcher(
            bluetoothMonitor: bluetoothMonitor,
            wifiMonitor: wifiMonitor,
            keychainMonitor: keychainMonitor,
            screenMonitor: screenMonitor,
            bonjourBrowser: bonjourBrowser,
            scriptExecutor: scriptExecutor
        )
        
        // Wait until initial check finishes so that background tasks do not cause a race condition
        while watcher.lastCheckTime == nil {
            try await Task.sleep(nanoseconds: 5_000_000) // Sleep 5ms
        }
    }
    
    override func tearDown() {
        watcher = nil
        bluetoothMonitor = nil
        wifiMonitor = nil
        keychainMonitor = nil
        screenMonitor = nil
        bonjourBrowser = nil
        scriptExecutor = nil
        super.tearDown()
    }
    
    func testInitialSyncState() {
        XCTAssertFalse(watcher.isBluetoothOnline)
        XCTAssertFalse(watcher.isWifiOnline)
        XCTAssertNil(watcher.wifiIPAddress)
        XCTAssertFalse(watcher.isKeychainActive)
        XCTAssertFalse(watcher.isMVDConnected)
        XCTAssertFalse(watcher.isVisionProOnline)
        XCTAssertNil(watcher.detectedVisionProName)
        XCTAssertEqual(watcher.menuBarIcon, "visionpro.badge.exclamationmark")
    }
    
    func testBluetoothStateTransition() async {
        await bluetoothMonitor.triggerUpdate(true)
        XCTAssertTrue(watcher.isBluetoothOnline)
        XCTAssertNotNil(watcher.lastCheckTime)
        
        // Still exclamation since other local systems are offline
        XCTAssertEqual(watcher.menuBarIcon, "visionpro.badge.exclamationmark")
    }
    
    func testWifiStateTransition() async {
        await wifiMonitor.triggerUpdate(true, ip: "192.168.1.50")
        XCTAssertTrue(watcher.isWifiOnline)
        XCTAssertEqual(watcher.wifiIPAddress, "192.168.1.50")
        XCTAssertNotNil(watcher.lastCheckTime)
        XCTAssertEqual(watcher.menuBarIcon, "visionpro.badge.exclamationmark")
    }
    
    func testKeychainStateTransition() async {
        await keychainMonitor.triggerUpdate(true)
        XCTAssertTrue(watcher.isKeychainActive)
        XCTAssertNotNil(watcher.lastCheckTime)
        XCTAssertEqual(watcher.menuBarIcon, "visionpro.badge.exclamationmark")
    }
    
    func testLocalSystemsReadyNoVisionPro() async {
        await bluetoothMonitor.triggerUpdate(true)
        await wifiMonitor.triggerUpdate(true, ip: "192.168.1.50")
        await keychainMonitor.triggerUpdate(true)
        
        XCTAssertEqual(watcher.menuBarIcon, "visionpro.slash")
    }
    
    func testLocalSystemsReadyWithVisionPro() async {
        await bluetoothMonitor.triggerUpdate(true)
        await wifiMonitor.triggerUpdate(true, ip: "192.168.1.50")
        await keychainMonitor.triggerUpdate(true)
        await bonjourBrowser.triggerUpdate(true, name: "Jeff's Vision Pro")
        
        XCTAssertTrue(watcher.isVisionProOnline)
        XCTAssertEqual(watcher.detectedVisionProName, "Jeff's Vision Pro")
        XCTAssertEqual(watcher.menuBarIcon, "visionpro")
    }
    
    func testMVDConnectedState() async {
        await bluetoothMonitor.triggerUpdate(true)
        await wifiMonitor.triggerUpdate(true, ip: "192.168.1.50")
        await keychainMonitor.triggerUpdate(true)
        await screenMonitor.triggerUpdate(true)
        
        XCTAssertTrue(watcher.isMVDConnected)
        XCTAssertEqual(watcher.menuBarIcon, "visionpro.slash")
    }
    
    func testRunCheckRestartsBonjour() async {
        let initialRestarts = bonjourBrowser.restartCount
        await watcher.runCheck()
        XCTAssertEqual(bonjourBrowser.restartCount, initialRestarts + 1)
    }
    
    func testLastCheckTimeStringFormatting() {
        watcher.lastCheckTime = nil
        XCTAssertEqual(watcher.lastCheckTimeString, "")
        watcher.lastCheckTime = Date()
        XCTAssertFalse(watcher.lastCheckTimeString.isEmpty)
    }
    
    func testConnectMVDScriptExecution() async {
        await bonjourBrowser.triggerUpdate(true, name: "TestVisionPro")
        
        watcher.connectMVD()
        
        XCTAssertEqual(scriptExecutor.executedScripts.count, 1)
        let script = scriptExecutor.executedScripts.first ?? ""
        XCTAssertTrue(script.contains("controlcenter-screen-mirroring"))
        XCTAssertTrue(script.contains("TestVisionPro"))
        XCTAssertTrue(script.contains("screen-mirroring-device-Sidecar"))
    }
    

}
