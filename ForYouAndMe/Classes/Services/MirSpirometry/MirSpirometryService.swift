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

    func mirSpirometryConnect()
    func mirSpirometryRunTest()
    func mirSpirometryDisconnect()
    func mirSpirometryStartDiscoverDevices()
    func mirSpirometryStopDiscoverDevices()
}
