//
//  MirSpirometryManager.swift
//  ForYouAndMe
//
//  Created by Andrea Gelati on 27/02/25.
//

import Foundation
import MirSmartDevice

final class MirSpirometryManager: NSObject, MirSpirometryService {

    // MARK: Properties
    
    fileprivate var localDevices: [SODeviceInfo] = []
    
    var devices: [SODeviceInfo]? {
        localDevices
    }

    // MARK: Functions

    func enableBluetooth() {
        guard let manager = SODeviceManager.shared() else { return }
        guard manager.bluetoothState() == .unknown else { return }
        manager.initBluetooth()
    }
    
    func connect() {
        let testResults = SOResults()
        testResults.pef_cLs = 1075
        testResults.fev1_cL = 399
        testResults.fvc_cL = -1
        testResults.fev1_fvc_pcnt = -1
        testResults.qualityCode = 507
        testResults.fev6_cL = -1
        testResults.fef2575_cLs = -1
        testResults.eVol_mL = 88
        testResults.pefTime_sec = 49
        testResults.pefTime_ms = 49
        testResults.deviceType = PeripheralType(rawValue: 2)
        testResults.resultTestType = SOTestType(rawValue: 1)
        testResults.deviceAtsStandard = AtsStandard(rawValue: 1)
        
        let testJSON = testResults.toJSON()
        print(testJSON)
        return

        guard let manager = SODeviceManager.shared() else { return }
        
        manager.setLogEnabled(true)
        manager.add(self)
        
        let demoDeviceID: String = "9FA26AD9-8E36-F163-CC7C-458380F07499" // Spirobank Smart 9FA26AD9-8E36-F163-CC7C-458380F07499
        manager.connect(demoDeviceID)
    }

    func disconnect() {
        guard let manager = SODeviceManager.shared() else { return }
        manager.disconnect()
    }

    func runTestPeakFlowFev1() {
        guard let manager = SODeviceManager.shared() else { return }
        guard let device = manager.connectedDevice else { return }

        let testType = SOTestType(rawValue: 1)
        let testTimeout: UInt8 = 15
        let turbineType = SOTurbineType(rawValue: 1)

        device.checkIfDeviceIsReady { value in
            guard value == true else { return }
            device.startTest(with: testType, endOfTestTimeout: testTimeout, turbineType: turbineType)
        }
    }

    func startDiscoverDevices() {
        guard let manager = SODeviceManager.shared() else { return }
        guard manager.bluetoothState() == .poweredOn else { return }
        manager.startDiscovery()
    }

    func stopDiscoverDevices() {
        guard let manager = SODeviceManager.shared() else { return }
        manager.stopDiscovery()
    }
}

// MARK: SODeviceManagerDelegate
extension MirSpirometryManager: SODeviceManagerDelegate {

    func deviceManager(_ deviceManager: SODeviceManager!, didDisconnectDevice device: SODevice!) {

    }
 
    func deviceManager(_ deviceManager: SODeviceManager!, didConnect device: SODevice!) {
        device.add(self)
    }
    
    func deviceManager(_ deviceManager: SODeviceManager!, didDiscoverDeviceWith deviceInfo: SODeviceInfo!) {
        guard localDevices.first(where: { $0.deviceID == deviceInfo.deviceID }) == nil else { return }
        localDevices.append(deviceInfo)
        
        print("didDiscoverDeviceWith ---")
        print("didDiscoverDeviceWith deviceID \(deviceInfo.deviceID ?? "")")
        print("didDiscoverDeviceWith name \(deviceInfo.name ?? "")")
        print("didDiscoverDeviceWith serialNumber \(deviceInfo.serialNumber ?? "")")
    }
    
    func deviceManager(_ deviceManager: SODeviceManager!, didUpdateBluetoothWith state: CBCentralManagerState) {
        
    }
    
    func deviceManager(_ deviceManager: SODeviceManager!, didFailToConnectDeviceWith deviceInfo: SODeviceInfo!) {
        
    }
    
    func deviceManager(_ deviceManager: SODeviceManager!, didReceiveWriteRequestError error: (any Error)!, for characteristic: CBCharacteristic!) {
        
    }
}

// MARK: SODeviceDelegate
extension MirSpirometryManager: SODeviceDelegate {
    func soDeviceDidRestartTest(_ soDevice: SODevice!) {
        
    }
    
    func soDeviceDidStopTest(_ soDevice: SODevice!) {
        
    }
    
    func soDeviceDidStartTest(_ soDevice: SODevice!) {
        
    }
    
    func soDevice(_ soDevice: SODevice!, didUpdate deviceStatus: SODeviceStatus!) {
        
    }
    
    func soDevice(_ soDevice: SODevice!, didReceive eofeIndicator: EndOfForcedExpirationIndicator) {
        
    }
    
    func soDevice(_ soDevice: SODevice!, heartBeatDetected bpm: Int32) {
        
    }
    
    func soDevice(_ soDevice: SODevice!, didUPdateResults results: SOResults!) {
        let resultsJSON = results.toJSON()
        print(resultsJSON)
    }
    
    func soDevice(_ soDevice: SODevice, didReceiveEcgInfo info: SOEcgPacketInfo) {
        
    }
    
    func soDevice(_ soDevice: SODevice, didReceiveEcgValues values: [NSNumber]) {
        
    }
    
    func soDevice(_ soDevice: SODevice, didUpdateEcgResults results: SOResultsEcg) {
        
    }
    
    func soDevice(_ soDevice: SODevice, didReceiveEcgProgress progress: Float) {
        
    }
    
    func soDeviceEcgTestShouldBeStarted(_ soDevice: SODevice) {
        
    }
    
    func soDevice(_ soDevice: SODevice!, didUPdateVcResults results: SOResultsVc!) {
        
    }
    
    func soDevice(_ soDevice: SODevice!, didUPdateMvvResults results: SOResultsMvv!) {
        
    }
    
    func soDevice(_ soDevice: SODevice!, didUpdateOximetryResults oximetryResults: SOResultsOximetry!) {
        
    }
    
    func soDevice(_ soDevice: SODevice, didUpdateEcgResultsList resultsList: [SOResultsEcg]) {
        
    }
    
    func soDevice(_ soDevice: SODevice!, didUpdateLastCommandStatus isSucceded: Bool) {
        
    }
    
    func soDevice(_ soDevice: SODevice!, didUPdateFvcPlusResults results: SOResultsFvcPlus!) {
        
    }
    
    func soDevice(_ soDevice: SODevice!, didReceiveRawPacket packetData: Data!, with packetType: SOParserRawPacketType) {
        
    }
    
    func soDevice(_ soDevice: SODevice!, didUpdateOximetryPletismographicValue ppmSignal: Int32) {
        
    }
    
    func soDevice(_ soDevice: SODevice!, didUpdateFlowTimeMonitoringValue value: Int32) {
        
    }
    
    func soDevice(_ soDevice: SODevice!, didUpdateHighResolutionCurvePoints curvePoints: NSMutableArray?) {
        
    }
    
    func soDevice(_ soDevice: SODevice!, didAttemptToFixFvcPlusActivation result: FixFvcPlusResult) {
        
    }
    
    func soDevice(_ soDevice: SODevice!, didUpdateFlowValue value: Float, isFirstPackage: Bool) {
        
    }
    
    func soDevice(_ soDevice: SODevice!, didReceiveSoftwareUpdateProgress progress: UInt, with status: UpdateStatus, error description: String!) {
        
    }
    
    func soDevice(_ soDevice: SODevice!, didUpdateVcVolumeTimePoint vcVtPoint: volumeTimePoint!, isFirstPackage: Bool) {
        
    }
    
    func soDevice(_ soDevice: SODevice!, didUpdateMvvVolumeTimePoint mvvVtPoint: volumeTimePoint!, isFirstPackage: Bool) {
        
    }
    
    func soDevice(_ soDevice: SODevice!, didUpdateFlowTimeMonitoringValue value: Int32, timeMilliseconds: Int) {
    
    }
    
    func soDevice(_ soDevice: SODevice!, didUpdateFvcPlusFlowVolumePoint fvPoint: flowVolmePoint!, isFirstPackage: Bool) {
        
    }
    
    func soDevice(_ soDevice: SODevice!, didUpdateOximetryRealTimeValuesWithSignal signal: Int32, spO2Value spO2: Int32, bpmValue bpm: Int32, warning: SOOximetryWarnings, isDataValid isdatavalid: Bool) {
        
    }
    
    func soDevice(_ soDevice: SODevice!, didUpdateOximetryRealTimeValuesWithSignal signal: Int32, spO2Value spO2: Int32, bpmValue bpm: Int32, isFingerOn fingerOn: Bool, isSearchingForPulse searchingForPulse: Bool, isDataValid dataValid: Bool, isBatteryLow batteryLow: Bool) {
        
    }
}

extension NSArray {
    
    public func toFloatArray() -> [Float] {
        compactMap {
            ($0 as? NSNumber)?.floatValue
        }
    }
}

extension Dictionary {
    
    public func toJSON() -> String {
        guard isEmpty == false else { return "" }
        guard let jsonData = try? JSONSerialization.data(withJSONObject: self, options: .prettyPrinted) else { return "" }
        guard let value = String(data: jsonData, encoding: .utf8) else { return "" }
        return value
    }
}

extension NSObject {
    
    public func toJSON() -> String {
        toDictionary()
            .toJSON()
    }
    
    private func convertValue(_ value: Any) -> Any {
        switch value {
        case let obj as NSObject where obj is NSString:
            return obj  // Directly return basic types
            
        case let obj as NSObject where obj is NSNumber:
            return obj  // Directly return basic types
            
        case let obj as NSObject where obj is NSDate:
            return obj  // Directly return basic types
            
        case let obj as NSObject:
            return obj.toDictionary()  // Convert custom objects to dictionary
            
        case let array as [NSObject]:
            return array.map { convertValue($0) }  // Convert array of objects
            
        case let dict as [String: NSObject]:
            return dict.mapValues { convertValue($0) }  // Convert dictionary values
            
        default:
            return value  // Return as-is for other types
        }
    }
    
    private func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        var count: UInt32 = 0
        let properties = class_copyPropertyList(type(of: self), &count)

        defer {
            free(properties)
        }
        
        for index in 0..<count {
            let property = properties?.advanced(by: Int(index)).pointee
            let name = String(cString: property_getName(property!))
            
            if let value = self.value(forKey: name) {
                dict[name] = convertValue(value)
            }
        }
        
        return dict
    }
}
