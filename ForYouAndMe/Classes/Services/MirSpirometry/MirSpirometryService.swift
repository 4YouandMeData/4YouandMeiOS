//
//  MirSpirometryService.swift
//  ForYouAndMe
//
//  Created by Andrea Gelati on 27/02/25.
//

import Foundation
import MirSmartDevice

protocol MirSpirometryService {
    
    // MARK: Properties
    
    var devices: [SODeviceInfo]? { get }

    // MARK: Functions

    func enableBluetooth()
    func connect()
    func runTestPeakFlowFev1()
    func disconnect()
    func startDiscoverDevices()
    func stopDiscoverDevices()
}
