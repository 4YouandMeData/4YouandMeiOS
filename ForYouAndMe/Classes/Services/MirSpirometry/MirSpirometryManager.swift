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

    func mirSpirometryConnect() {
        guard let manager = SODeviceManager.shared() else { return }
        
        manager.setLogEnabled(true)
        manager.add(self)
        manager.initBluetooth()

        let demoDeviceID: String = "SM-009-Z125247" // Spirobank Smart SM-009-Z125247
        manager.connect(demoDeviceID)
    }

    func mirSpirometryDisconnect() {
        guard let manager = SODeviceManager.shared() else { return }
        manager.disconnect()
    }

    func mirSpirometryRunTest() {
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

    func mirSpirometryStartDiscoverDevices() {
        guard let manager = SODeviceManager.shared() else { return }
        guard manager.bluetoothState() == .poweredOn else { return }
        manager.startDiscovery()
    }

    func mirSpirometryStopDiscoverDevices() {
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
    
    private func serializeValue(_ value: Any) -> Any {
        if let nsObject = value as? NSObject {
            return nsObject.toDictionary() // convert NSObject properties (recursively)
        } else if let array = value as? [Any] {
            return array.map { serializeValue($0) } // convert each array element
        } else if let dict = value as? [String: Any] {
            return dict.mapValues { serializeValue($0) } // convert each dictionary entry
        }
        
        return value // return raw value (String, Int, etc.)
    }
    
    private func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        var classType: AnyClass? = type(of: self)
        
        while let currentClass = classType {
            var propertyCount: UInt32 = 0

            defer {
                classType = class_getSuperclass(currentClass) // move up the class hierarchy
            }

            if let properties = class_copyPropertyList(currentClass, &propertyCount) {
                defer {
                    free(properties)
                }

                for index in 0..<Int(propertyCount) {
                    let property = properties[index]
                    if let propertyName = String(cString: property_getName(property), encoding: .utf8) {
                        if let value = self.value(forKey: propertyName) {
                            dict[propertyName] = serializeValue(value)
                        }
                    }
                }
            }
        }
        
        return dict
    }
}
