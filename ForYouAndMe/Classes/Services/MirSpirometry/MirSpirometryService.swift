//
//  MirSpirometryService.swift
//  ForYouAndMe
//
//  Created by Andrea Gelati on 27/02/25.
//

import Foundation
import MirSmartDevice

/// Protocol that defines the main functionalities and events needed to interact
/// with a MIR spirometer device, including discovery, connection, test execution, and result handling.
protocol MirSpirometryService {
    
    // MARK: - Properties
    
    /// A list of the devices discovered during the scanning process.
    var devices: [SODeviceInfo]? { get }
    
    // MARK: - Callbacks / Events
    
    /// This closure is triggered whenever a new device is discovered,
    /// passing the updated list of devices.
    var onDeviceDiscovered: (([SODeviceInfo]) -> Void)? { get set }
    
    /// This closure is triggered when the device connection succeeds.
    var onDeviceConnected: (() -> Void)? { get set }
    
    /// Triggered when the device is disconnected.
    var onDeviceDisconnected: (() -> Void)? { get set }
    
    /// This closure is triggered when the device connection fails or an error occurs.
    var onDeviceConnectFailed: ((Error?) -> Void)? { get set }
    
    /// This closure is triggered when the spirometry test (PeakFlow/FEV1) actually starts.
    var onTestDidStart: (() -> Void)? { get set }
    
    /// This closure is triggered when the spirometry test produces its final results.
    /// The `String` parameter typically contains the test data in JSON format.
    var onTestResults: ((SOResults) -> Void)? { get set }
    
    /// Triggered when test value is changed
    var onFlowValueUpdated: ((SODevice, Float, Bool) -> Void)? { get set }
    
    /// Callback on every change of bluetooth state
    var onBluetoothStateChanged: ((CBCentralManagerState) -> Void)? { get set }
    
    // MARK: - Functions
    
    /// Initializes or enables Bluetooth if required.
    func enableBluetooth()
    
    /// Check if Bluetooth if on.
    func isPoweredOn() -> Bool
    
    /// Starts discovering MIR spirometer devices.
    func startDiscoverDevices()
    
    /// Stops discovering MIR spirometer devices.
    func stopDiscoverDevices()
    
    /// Connects to the selected device.
    func connect(deviceID: String?)
    
    /// Disconnects the currently connected device, if any.
    func disconnect()
    
    /// Starts the PeakFlow/FEV1 spirometry test on the connected device.
    func runTestPeakFlowFev1()
}
