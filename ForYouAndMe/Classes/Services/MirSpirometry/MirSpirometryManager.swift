//
//  MirSpirometryManager.swift
//  ForYouAndMe
//
//  Created by Andrea Gelati on 27/02/25.
//

import Foundation
import MirSmartDevice

/// This class manages the interactions with a MIR spirometer device,
/// performing discovery, connection, and test operations.
/// It conforms to the `MirSpirometryService` protocol, defining
/// the necessary methods and callbacks for each phase.
final class MirSpirometryManager: NSObject, MirSpirometryService {
    
    // MARK: - Internal Storage
    
    /// Internal array used to store the discovered devices.
    fileprivate var localDevices: [SODeviceInfo] = []
    
    // MARK: - MirSpirometryService Protocol Properties
    
    /// Returns the list of discovered devices.
    var devices: [SODeviceInfo]? {
        return localDevices
    }
    
    // MARK: - MirSpirometryService Protocol Callbacks
    
    /// Triggered whenever the scanning process finds a new device,
    /// passing the updated device list.
    var onDeviceDiscovered: (([SODeviceInfo]) -> Void)?
    
    /// Triggered when the device connection succeeds.
    var onDeviceConnected: (() -> Void)?
    
    /// Triggered when the device connection fails or encounters an error.
    var onDeviceConnectFailed: ((Error?) -> Void)?
    
    /// Triggered when the spirometry test actually starts on the device.
    var onTestDidStart: (() -> Void)?
    
    /// Triggered when the spirometry test finishes and produces final results.
    /// The `String` parameter typically contains JSON-formatted data.
    var onTestResults: ((SOResults) -> Void)?
    
    var onFlowValueUpdated: ((SODevice, Float, Bool) -> Void)?
    
    // MARK: - MirSpirometryService Protocol Methods
    
    /// Initializes or enables Bluetooth if required.
    /// In MirSmartDevice, calling `initBluetooth()` on the shared manager
    /// might be enough to handle initialization.
    func enableBluetooth() {
        guard let manager = SODeviceManager.shared() else { return }
        // If the Bluetooth state is unknown, you can manually initialize it:
        if manager.bluetoothState() == .unknown {
            manager.initBluetooth()
        }
    }
    
    func isPoweredOn() -> Bool {
        guard let manager = SODeviceManager.shared() else { return false }
        // If the Bluetooth state is unknown, you can manually initialize it:
        let state = manager.bluetoothState()
        return state == .poweredOn
    }
    
    /// Starts discovering MIR spirometer devices.
    func startDiscoverDevices() {
        guard let manager = SODeviceManager.shared() else { return }
        // Enable logs for debugging purposes, if needed.
        manager.setLogEnabled(true)
                
        // Add this manager as a delegate to receive events.
        manager.add(self)
        // Begin discovery.
        manager.startDiscovery()
    }
    
    /// Stops discovering MIR spirometer devices.
    func stopDiscoverDevices() {
        guard let manager = SODeviceManager.shared() else { return }
        manager.stopDiscovery()
    }
    
    /// Connects to a device. This example uses a hard-coded demo Device ID,
    /// but you can also store a user-selected ID or pass it as a parameter.
    func connect(deviceID: String?) {
        guard let manager = SODeviceManager.shared() else { return }
        
        manager.setLogEnabled(true)
        manager.add(self)
        
        manager.connect(deviceID ?? "9FA26AD9-8E36-F163-CC7C-458380F07499")
    }
    
    /// Disconnects the currently connected device, if any.
    func disconnect() {
        guard let manager = SODeviceManager.shared() else { return }
        manager.disconnect()
    }
    
    /// Runs the PeakFlow/FEV1 spirometry test on the connected device.
    func runTestPeakFlowFev1() {
        guard let manager = SODeviceManager.shared(),
              let device = manager.connectedDevice else {
            return
        }
        
        // SOTestType(1) usually indicates FEV1 test, but confirm with MirSmartDevice docs.
        let testType = SOTestType(rawValue: TestPeakFlowFev1.rawValue)
        let testTimeout: UInt8 = 15
        let turbineType = SOTurbineType(rawValue: 1)
        
        // Check if the device is ready before starting the test.
        device.checkIfDeviceIsReady { [weak self] isReady in
            guard let self = self, isReady == true else { return }
            device.startTest(with: testType,
                             endOfTestTimeout: testTimeout,
                             turbineType: turbineType)
        }
    }
}

// MARK: - SODeviceManagerDelegate
extension MirSpirometryManager: SODeviceManagerDelegate {
    
    /// Called when a new device is discovered during the scanning process.
    func deviceManager(_ deviceManager: SODeviceManager!,
                       didDiscoverDeviceWith deviceInfo: SODeviceInfo!) {
        
        // Avoid duplicates, then add the new device to our list.
        guard localDevices.first(where: { $0.deviceID == deviceInfo.deviceID }) == nil else { return }
        localDevices.append(deviceInfo)
        
        // Notify observers of the updated device list.
        onDeviceDiscovered?(localDevices)
    }
    
    /// Called when the device has successfully connected.
    func deviceManager(_ deviceManager: SODeviceManager!,
                       didConnect device: SODevice!) {
        
        // We also need to set this class as the device's delegate to receive test events.
        device.add(self)
        
        // Trigger the callback for a successful connection.
        onDeviceConnected?()
    }
    
    /// Called if the device fails to connect.
    func deviceManager(_ deviceManager: SODeviceManager!,
                       didFailToConnectDeviceWith deviceInfo: SODeviceInfo!) {
        
        // In many scenarios, MirSmartDevice doesn't provide a specific error object here,
        // so we pass nil.
        onDeviceConnectFailed?(nil)
    }
    
    /// Called whenever the Bluetooth state changes.
    /// For instance, you can detect when Bluetooth is powered off/on.
    func deviceManager(_ deviceManager: SODeviceManager!,
                       didUpdateBluetoothWith state: CBCentralManagerState) {
        // You can optionally handle different Bluetooth states if needed.
    }
    
    /// Called when a device is disconnected.
    func deviceManager(_ deviceManager: SODeviceManager!,
                       didDisconnectDevice device: SODevice!) {
        // You might want to handle the disconnection, e.g., reset UI state.
    }
    
    /// Called if there's an error writing data to a characteristic.
    func deviceManager(_ deviceManager: SODeviceManager!,
                       didReceiveWriteRequestError error: (any Error)!,
                       for characteristic: CBCharacteristic!) {
        // Optionally handle write request errors.
    }
}

// MARK: - SODeviceDelegate
extension MirSpirometryManager: SODeviceDelegate {
    
    /// Called when the device restarts the test (e.g., an internal reset).
    func soDeviceDidRestartTest(_ soDevice: SODevice!) {
        // Optionally handle a test restart event if needed.
    }
    
    /// Called when the device stops the test.
    func soDeviceDidStopTest(_ soDevice: SODevice!) {
        // This might occur if the user stops the test prematurely or the device times out.
        print("Stop Test")
    }
    
    /// Called when the device begins the test.
    func soDeviceDidStartTest(_ soDevice: SODevice!) {
        onTestDidStart?()
    }
    
    /// Called whenever the device updates its general status.
    func soDevice(_ soDevice: SODevice!,
                  didUpdate deviceStatus: SODeviceStatus!) {
        // Optionally handle status updates (e.g., battery level or warnings).
    }
    
    /// Called when the device signals the end of forced expiration (EOF).
    func soDevice(_ soDevice: SODevice!,
                  didReceive eofeIndicator: EndOfForcedExpirationIndicator) {
        // You can track the forced expiration if needed.
    }
    
    /// Called if the device detects a heartbeat (not typically used in spirometry).
    func soDevice(_ soDevice: SODevice!,
                  heartBeatDetected bpm: Int32) {
        // Possibly relevant if the device also measures pulse or oximetry.
    }
    
    /// Called when the device provides updated spirometry results.
    func soDevice(_ soDevice: SODevice!,
                  didUPdateResults results: SOResults!) {
        // Convert the results to JSON string for easier handling.
//        let resultsJSON = results.toJSON()
        onTestResults?(results)
    }
    
    // MARK: - Additional Delegate Methods
    
    // Below are optional method stubs from SODeviceDelegate that you can implement
    // if your workflow requires them. Currently, they are left empty.
    
    func soDevice(_ soDevice: SODevice,
                  didReceiveEcgInfo info: SOEcgPacketInfo) { }
    func soDevice(_ soDevice: SODevice,
                  didReceiveEcgValues values: [NSNumber]) { }
    func soDevice(_ soDevice: SODevice,
                  didUpdateEcgResults results: SOResultsEcg) { }
    func soDevice(_ soDevice: SODevice,
                  didReceiveEcgProgress progress: Float) { }
    func soDeviceEcgTestShouldBeStarted(_ soDevice: SODevice) { }
    
    func soDevice(_ soDevice: SODevice!,
                  didUPdateVcResults results: SOResultsVc!) { }
    func soDevice(_ soDevice: SODevice!,
                  didUPdateMvvResults results: SOResultsMvv!) { }
    func soDevice(_ soDevice: SODevice!,
                  didUpdateOximetryResults oximetryResults: SOResultsOximetry!) { }
    func soDevice(_ soDevice: SODevice,
                  didUpdateEcgResultsList resultsList: [SOResultsEcg]) { }
    func soDevice(_ soDevice: SODevice!,
                  didUpdateLastCommandStatus isSucceded: Bool) { }
    func soDevice(_ soDevice: SODevice!,
                  didUPdateFvcPlusResults results: SOResultsFvcPlus!) { }
    func soDevice(_ soDevice: SODevice!,
                  didReceiveRawPacket packetData: Data!,
                  with packetType: SOParserRawPacketType) { }
    
    func soDevice(_ soDevice: SODevice!,
                  didUpdateOximetryPletismographicValue ppmSignal: Int32) { }
    
    func soDevice(_ soDevice: SODevice!,
                  didUpdateFlowTimeMonitoringValue value: Int32) { }
    
    func soDevice(_ soDevice: SODevice!,
                  didUpdateHighResolutionCurvePoints curvePoints: NSMutableArray?) { }
    
    func soDevice(_ soDevice: SODevice!,
                  didAttemptToFixFvcPlusActivation result: FixFvcPlusResult) { }
    
    func soDevice(_ soDevice: SODevice!,
                  didUpdateFlowValue value: Float,
                  isFirstPackage: Bool) {
        onFlowValueUpdated?(soDevice, value, isFirstPackage)
    }
    
    func soDevice(_ soDevice: SODevice!,
                  didReceiveSoftwareUpdateProgress progress: UInt,
                  with status: UpdateStatus,
                  error description: String!) { }
    
    func soDevice(_ soDevice: SODevice!,
                  didUpdateVcVolumeTimePoint vcVtPoint: volumeTimePoint!,
                  isFirstPackage: Bool) { }
    
    func soDevice(_ soDevice: SODevice!,
                  didUpdateMvvVolumeTimePoint mvvVtPoint: volumeTimePoint!,
                  isFirstPackage: Bool) { }
    
    func soDevice(_ soDevice: SODevice!,
                  didUpdateFlowTimeMonitoringValue value: Int32,
                  timeMilliseconds: Int) { }
    
    func soDevice(_ soDevice: SODevice!,
                  didUpdateFvcPlusFlowVolumePoint fvPoint: flowVolmePoint!,
                  isFirstPackage: Bool) { }
    
    func soDevice(_ soDevice: SODevice!,
                  didUpdateOximetryRealTimeValuesWithSignal signal: Int32,
                  spO2Value spO2: Int32,
                  bpmValue bpm: Int32,
                  warning: SOOximetryWarnings,
                  isDataValid isdatavalid: Bool) { }
    
    func soDevice(_ soDevice: SODevice!,
                  didUpdateOximetryRealTimeValuesWithSignal signal: Int32,
                  spO2Value spO2: Int32,
                  bpmValue bpm: Int32,
                  isFingerOn fingerOn: Bool,
                  isSearchingForPulse searchingForPulse: Bool,
                  isDataValid dataValid: Bool,
                  isBatteryLow batteryLow: Bool) { }
}

extension NSArray {
    
    public func toFloatArray() -> [Float] {
        compactMap {
            ($0 as? NSNumber)?.floatValue
        }
    }
}

//extension Dictionary {
//    
//    public func toJSON() -> String {
//        guard isEmpty == false else { return "" }
//        guard let jsonData = try? JSONSerialization.data(withJSONObject: self, options: .prettyPrinted) else { return "" }
//        guard let value = String(data: jsonData, encoding: .utf8) else { return "" }
//        return value
//    }
//}
//
//extension NSObject {
//    
//    public func toJSON() -> String {
//        toDictionary()
//            .toJSON()
//    }
//    
//    private func convertValue(_ value: Any) -> Any {
//        switch value {
//        case let obj as NSObject where obj is NSString:
//            return obj  // Directly return basic types
//            
//        case let obj as NSObject where obj is NSNumber:
//            return obj  // Directly return basic types
//            
//        case let obj as NSObject where obj is NSDate:
//            return obj  // Directly return basic types
//            
//        case let obj as NSObject:
//            return obj.toDictionary()  // Convert custom objects to dictionary
//            
//        case let array as [NSObject]:
//            return array.map { convertValue($0) }  // Convert array of objects
//            
//        case let dict as [String: NSObject]:
//            return dict.mapValues { convertValue($0) }  // Convert dictionary values
//            
//        default:
//            return value  // Return as-is for other types
//        }
//    }
//    
//    private func toDictionary() -> [String: Any] {
//        var dict: [String: Any] = [:]
//        var count: UInt32 = 0
//        let properties = class_copyPropertyList(type(of: self), &count)
//
//        defer {
//            free(properties)
//        }
//        
//        for index in 0..<count {
//            let property = properties?.advanced(by: Int(index)).pointee
//            let name = String(cString: property_getName(property!))
//            
//            if let value = self.value(forKey: name) {
//                dict[name] = convertValue(value)
//            }
//        }
//        
//        return dict
//    }
//}

struct SOResultsCodable: Codable {
    var pefcLs: Int32
    var fev1cL: Int32
    var fvccL: Int32
    var fev1fvcpcnt: Float
    var qualityCode: Int32
    var fev6cL: Int32
    var fef2575cLs: Int32
    var eVolmL: Int32
    var pefTimems: Int32
    var resultTestType: Int
    var deviceAtsStandard: Int
    var deviceType: Int
}

extension SOResults {
    func toCodable() -> SOResultsCodable {
        return SOResultsCodable(
            pefcLs: self.pef_cLs,
            fev1cL: self.fev1_cL,
            fvccL: self.fvc_cL,
            fev1fvcpcnt: self.fev1_fvc_pcnt,
            qualityCode: self.qualityCode,
            fev6cL: self.fev6_cL,
            fef2575cLs: self.fef2575_cLs,
            eVolmL: self.eVol_mL,
            pefTimems: self.pefTime_ms,
            resultTestType: Int(self.resultTestType.rawValue),
            deviceAtsStandard: Int(self.deviceAtsStandard.rawValue),
            deviceType: Int(self.deviceType.rawValue)
        )
    }

    func toJSON() -> String? {
        let codableObject = self.toCodable()
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        guard let jsonData = try? encoder.encode(codableObject) else {
            return nil
        }

        return String(data: jsonData, encoding: .utf8)
    }
    
    func toDictionary() -> [String: Any]? {
        let codableObject = self.toCodable()
        guard let data = try? JSONEncoder().encode(codableObject),
              let dict = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any]
        else {
            return nil
        }
        return dict
    }
}
