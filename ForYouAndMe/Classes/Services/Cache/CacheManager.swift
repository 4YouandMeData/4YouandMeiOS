//
//  CacheManager.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 24/04/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import Foundation

class CacheManager: CacheService {
    
    enum CacheManagerKey: String {
        case globalConfig
        case accessToken
        case deviceUDID
        case userKey
        case infoMessages
        case firstUserAbsoluteLocationKey
        case excludedUserDataAggregationIdsKey
        // BatchEventUploader keys
        case batchEventUploadercCurrentBuffer
        case batchEventUploaderArchivedBuffers
        case batchEventUploaderDate
        case batchEventUploaderRecordInterval
        // HealthUploader keys
        case pendingUploadDataType
        case lastSampleUploadAnchor
        case lastUploadSequenceCompletionDate
        case lastUploadSequenceStartingDate
        case firstSuccessfulSampleUploadDate
    }
    
    private let mainUserDefaults = UserDefaults.standard
    
    var user: User? {
        get {return self.load(forKey: CacheManagerKey.userKey.rawValue)}
        set {self.save(encodable: newValue, forKey: CacheManagerKey.userKey.rawValue)}
    }
    
    var infoMessages: [MessageInfo]? {
        get {return self.load(forKey: CacheManagerKey.infoMessages.rawValue)}
        set {self.save(encodable: newValue, forKey: CacheManagerKey.infoMessages.rawValue)}
    }
    
    var deviceUDID: String? {
        get {
            var UDID = self.getString(forKey: CacheManagerKey.deviceUDID.rawValue)
            if UDID == nil || UDID?.isEmpty == true {
                UDID = UIDevice.current.identifierForVendor?.uuidString
                if let deviceUDID = UDID {
                    self.saveString(deviceUDID, forKey: CacheManagerKey.deviceUDID.rawValue)
                }
            }
            return UDID ?? ""
        }
        set {
            self.saveString(newValue, forKey: CacheManagerKey.deviceUDID.rawValue)
        }
    }
    
    var firstUserAbsoluteLocation: UserLocation? {
        get {return self.load(forKey: CacheManagerKey.firstUserAbsoluteLocationKey.rawValue)}
        set {self.save(encodable: newValue, forKey: CacheManagerKey.firstUserAbsoluteLocationKey.rawValue)}
    }
    
    var excludedUserDataAggregationIds: [String]? {
        get {return self.load(forKey: CacheManagerKey.excludedUserDataAggregationIdsKey.rawValue)}
        set {self.save(encodable: newValue, forKey: CacheManagerKey.excludedUserDataAggregationIdsKey.rawValue)}
    }
        
    // MARK: - Private methods
    
    private func save<T>(encodable: T?, forKey key: String) where T: Encodable {
        if let encodable = encodable {
            let encoder = JSONEncoder()
            if let encoded = try? encoder.encode(encodable) {
                self.mainUserDefaults.set(encoded, forKey: key)
            }
        } else {
            self.reset(forKey: key)
        }
    }
    
    private func load<T>(forKey key: String) -> T? where T: Decodable {
        if let encodedData = self.mainUserDefaults.object(forKey: key) as? Data {
            let decoder = JSONDecoder()
            if let object = try? decoder.decode(T.self, from: encodedData) {
                return object
            }
        }
        return nil
    }
    
    private func saveNSSecureCoding<T>(object: T?, forKey key: String) where T: NSSecureCoding {
        if let object = object {
            if let encoded = try? NSKeyedArchiver.archivedData(withRootObject: object, requiringSecureCoding: true) {
                self.mainUserDefaults.set(encoded, forKey: key)
            }
        } else {
            self.reset(forKey: key)
        }
    }
    
    private func loadNSSecureCoding<T>(forKey key: String) -> T? where T: NSSecureCoding & NSObject {
        if let encodedData = self.mainUserDefaults.object(forKey: key) as? Data {
            let allowedClasses: [AnyClass] = [
                T.self,
                NSString.self,
                NSDictionary.self,
                NSDate.self
            ]

            return try? NSKeyedUnarchiver.unarchivedObject(ofClasses: allowedClasses, from: encodedData) as? T
        }
        return nil
    }
    
    private func saveString(_ value: String?, forKey key: String) {
        if let value = value {
            self.mainUserDefaults.set(value, forKey: key)
        } else {
            self.reset(forKey: key)
        }
    }
    
    private func getString(forKey key: String) -> String? {
        return self.mainUserDefaults.string(forKey: key)
    }
    
    private func reset(forKey key: String) {
        self.mainUserDefaults.removeObject(forKey: key)
    }
}

// MARK: - RepositoryStorage

extension CacheManager: RepositoryStorage {
    
    var globalConfig: GlobalConfig? {
        get { self.load(forKey: CacheManagerKey.globalConfig.rawValue) }
        set { self.save(encodable: newValue, forKey: CacheManagerKey.globalConfig.rawValue) }
    }
}

// MARK: - NetworkStorage

extension CacheManager: NetworkStorage {
    
    var accessToken: String? {
        get { self.getString(forKey: CacheManagerKey.accessToken.rawValue) }
        set { self.saveString(newValue, forKey: CacheManagerKey.accessToken.rawValue) }
    }
}

// MARK: - BatchEventUploaderStorage

extension CacheManager.CacheManagerKey {
    func getKey(forUploaderIdentifier uploaderIdentifier: String) -> String {
        return uploaderIdentifier + "." + self.rawValue
    }
    
    static func getBatchEventUploaderDateKey(forUploaderIdentifier uploaderIdentifier: String,
                                             dateType: BatchEventUploaderDateType) -> String {
        return uploaderIdentifier + "." + dateType.rawValue + "." + CacheManager.CacheManagerKey.batchEventUploaderDate.rawValue
    }
}

extension CacheManager: BatchEventUploaderStorage {
    
    // MARK: - Record & Buffers
    
    func appendRecord<Record: Codable>(forUploaderIdentifier uploaderIdentifier: String, record: Record) {
        let currentBufferKey = CacheManagerKey.batchEventUploadercCurrentBuffer.getKey(forUploaderIdentifier: uploaderIdentifier)
        var buffer: Buffer<Record> = self.load(forKey: currentBufferKey) ?? Buffer(records: [])
        buffer.records.append(record)
        self.save(encodable: buffer, forKey: currentBufferKey)
    }
    
    func archiveCurrentBuffer<Record: Codable>(forUploaderIdentifier uploaderIdentifier: String, bufferLimit: Int, type: Record.Type) {
        let currentBufferKey = CacheManagerKey.batchEventUploadercCurrentBuffer.getKey(forUploaderIdentifier: uploaderIdentifier)
        let buffer: Buffer<Record> = self.load(forKey: currentBufferKey) ?? Buffer(records: [])
        self.appendArchivedBuffer(forUploaderIdentifier: uploaderIdentifier, buffer: buffer, bufferLimit: bufferLimit)
        self.reset(forKey: currentBufferKey)
    }
    
    func removeOldestArchivedBuffer<Record: Codable>(forUploaderIdentifier uploaderIdentifier: String, type: Record.Type) {
        var buffers: [Buffer<Record>] = self.getArchivedBuffers(forUploaderIdentifier: uploaderIdentifier)
        if buffers.count > 0 {
            _ = buffers.removeFirst()
            let archivedBuffersKey = CacheManagerKey.batchEventUploaderArchivedBuffers.getKey(forUploaderIdentifier: uploaderIdentifier)
            self.save(encodable: buffers, forKey: archivedBuffersKey)
        }
    }
    
    func getOldestArchivedBuffer<Record: Codable>(forUploaderIdentifier uploaderIdentifier: String) -> Buffer<Record>? {
        return self.getArchivedBuffers(forUploaderIdentifier: uploaderIdentifier).first
    }
    
    func resetAllBuffers(forUploaderIdentifier uploaderIdentifier: String) {
        self.reset(forKey: CacheManagerKey.batchEventUploadercCurrentBuffer.getKey(forUploaderIdentifier: uploaderIdentifier))
        self.reset(forKey: CacheManagerKey.batchEventUploaderArchivedBuffers.getKey(forUploaderIdentifier: uploaderIdentifier))
    }
    
    private func getArchivedBuffers<Record: Codable>(forUploaderIdentifier uploaderIdentifier: String) -> [Buffer<Record>] {
        let archivedBuffersKey = CacheManagerKey.batchEventUploaderArchivedBuffers.getKey(forUploaderIdentifier: uploaderIdentifier)
        return self.load(forKey: archivedBuffersKey) ?? []
    }
    
    private func appendArchivedBuffer<Record: Codable>(forUploaderIdentifier uploaderIdentifier: String,
                                                       buffer: Buffer<Record>,
                                                       bufferLimit: Int) {
        var buffers: [Buffer<Record>] = self.getArchivedBuffers(forUploaderIdentifier: uploaderIdentifier)
        buffers.append(buffer)
        if buffers.count > bufferLimit {
            buffers.removeFirst()
        }
        let archivedBuffersKey = CacheManagerKey.batchEventUploaderArchivedBuffers.getKey(forUploaderIdentifier: uploaderIdentifier)
        self.save(encodable: buffers, forKey: archivedBuffersKey)
    }
    
    // MARK: - Dates
    
    func getBatchEventUploaderDate(forUploaderIdentifier uploaderIdentifier: String, dateType: BatchEventUploaderDateType) -> Date? {
        return self.load(forKey: CacheManagerKey.getBatchEventUploaderDateKey(forUploaderIdentifier: uploaderIdentifier,
                                                                              dateType: dateType))
    }
    
    func saveBatchEventUploaderDate(forUploaderIdentifier uploaderIdentifier: String, dateType: BatchEventUploaderDateType, date: Date) {
        self.save(encodable: date, forKey: CacheManagerKey.getBatchEventUploaderDateKey(forUploaderIdentifier: uploaderIdentifier,
                                                                                        dateType: dateType))
    }
    
    func resetBatchEventUploaderDate(forUploaderIdentifier uploaderIdentifier: String, dateType: BatchEventUploaderDateType) {
        self.reset(forKey: CacheManagerKey.getBatchEventUploaderDateKey(forUploaderIdentifier: uploaderIdentifier,
                                                                        dateType: dateType))
    }
    
    // MARK: - Record Interval
    
    func getRecordInterval(forUploaderIdentifier uploaderIdentifier: String) -> TimeInterval? {
        return self.load(forKey: CacheManagerKey.batchEventUploaderRecordInterval.getKey(forUploaderIdentifier: uploaderIdentifier))
    }
    
    func saveRecordInterval(forUploaderIdentifier uploaderIdentifier: String, timeInterval: TimeInterval) {
        self.save(encodable: timeInterval,
                  forKey: CacheManagerKey.batchEventUploaderRecordInterval.getKey(forUploaderIdentifier: uploaderIdentifier))
    }
}

// MARK: - HealthSampleUploaderStorage

extension CacheManager.CacheManagerKey {
    static func getLastSampleUploadAnchorKey(forHealthDataTypeIdentifier healthDataTypeIdentifier: HealthDataType) -> String {
        return CacheManager.CacheManagerKey.lastSampleUploadAnchor.rawValue + "." + healthDataTypeIdentifier.rawValue
    }
}

extension CacheManager: HealthSampleUploaderStorage {
    var uploadStartDate: Date? {
        get { self.load(forKey: CacheManagerKey.firstSuccessfulSampleUploadDate.rawValue) }
        set { self.save(encodable: newValue, forKey: CacheManagerKey.firstSuccessfulSampleUploadDate.rawValue) }
    }
    
    func saveLastSampleUploadAnchor<T: NSSecureCoding>(_ anchor: T?, forDataType dataType: HealthDataType) {
        self.saveNSSecureCoding(object: anchor, forKey: CacheManagerKey.getLastSampleUploadAnchorKey(forHealthDataTypeIdentifier: dataType))
    }
    
    func loadLastSampleUploadAnchor<T: NSSecureCoding & NSObject>(forDataType dataType: HealthDataType) -> T? {
        return self.loadNSSecureCoding(forKey: CacheManagerKey.getLastSampleUploadAnchorKey(forHealthDataTypeIdentifier: dataType))
    }
}

// MARK: - HealthSampleUploadManagerStorage

extension CacheManager: HealthSampleUploadManagerStorage {
    var lastUploadSequenceCompletionDate: Date? {
        get { self.load(forKey: CacheManagerKey.lastUploadSequenceCompletionDate.rawValue) }
        set { self.save(encodable: newValue, forKey: CacheManagerKey.lastUploadSequenceCompletionDate.rawValue) }
    }
    
    var lastUploadSequenceStartingDate: Date? {
        get { self.load(forKey: CacheManagerKey.lastUploadSequenceStartingDate.rawValue) }
        set { self.save(encodable: newValue, forKey: CacheManagerKey.lastUploadSequenceStartingDate.rawValue) }
    }
    
    var pendingUploadDataType: HealthDataType? {
        get {
            guard let dataTypeString = self.getString(forKey: CacheManagerKey.pendingUploadDataType.rawValue) else {
                return nil
            }
            return HealthDataType(rawValue: dataTypeString)
        }
        set { self.saveString(newValue?.rawValue, forKey: CacheManagerKey.pendingUploadDataType.rawValue) }
    }
}

// MARK: - Debug

#if DEBUG
extension CacheManager {
    func resetHealthKitCache() {
        self.pendingUploadDataType = nil
        self.lastUploadSequenceCompletionDate = nil
        self.lastUploadSequenceStartingDate = nil
        self.uploadStartDate = nil
        HealthDataType.allCases.forEach { dataType in
            self.reset(forKey: CacheManagerKey.getLastSampleUploadAnchorKey(forHealthDataTypeIdentifier: dataType))
        }
        print("HealthSampleUpload cache purged")
    }
}

import MirSmartDevice

// MARK: Mir Spirometry
extension CacheManager {
    func uploadMirSpirometryData() {
        
        // Setup tasks:
        // 1. Create new Task
        // 2. Create new Permission for the device
        
        // device connection
        // create session
        // session complete, extract data
        // convert data to JSON
        // upload JSON to the server

        
        let manager = SODeviceManager.shared()
        if let manager {
            manager.setLogEnabled(true)
            manager.add(deviceManagerDelegate)
            manager.initBluetooth()
            manager.connectedDevice.add(deviceDelegate)
        }
    }
}

let deviceManagerDelegate = DeviceManagerDelegate()
let deviceDelegate = DeviceDelegate()

final class DeviceDelegate: NSObject, SODeviceDelegate {
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

final class DeviceManagerDelegate: NSObject, SODeviceManagerDelegate {
    
    func deviceManager(_ deviceManager: SODeviceManager!, didDisconnectDevice device: SODevice!) {
        
    }
 
    func deviceManager(_ deviceManager: SODeviceManager!, didConnect device: SODevice!) {
        
    }
    
    func deviceManager(_ deviceManager: SODeviceManager!, didDiscoverDeviceWith deviceInfo: SODeviceInfo!) {
        
    }
    
    func deviceManager(_ deviceManager: SODeviceManager!, didUpdateBluetoothWith state: CBCentralManagerState) {
        
    }
    
    func deviceManager(_ deviceManager: SODeviceManager!, didFailToConnectDeviceWith deviceInfo: SODeviceInfo!) {
        
    }
    
    func deviceManager(_ deviceManager: SODeviceManager!, didReceiveWriteRequestError error: (any Error)!, for characteristic: CBCharacteristic!) {
        
    }
}

#endif

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
            return nsObject.toDictionary() // Recursively convert NSObject properties
        } else if let array = value as? [Any] {
            return array.map { serializeValue($0) } // Convert each array element
        } else if let dict = value as? [String: Any] {
            return dict.mapValues { serializeValue($0) } // Convert each dictionary entry
        }
        
        return value // Return raw value (String, Int, etc.)
    }
    
    private func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        var classType: AnyClass? = type(of: self)
        
        while let currentClass = classType {
            var propertyCount: UInt32 = 0

            defer {
                classType = class_getSuperclass(currentClass) // Move up the class hierarchy
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
