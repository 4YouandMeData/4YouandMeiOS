//
//  DeviceService.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 29/01/21.
//

import Foundation

protocol DeviceService {
    func onLocationPermissionChanged()
    var locationServicesAvailable: Bool { get }
}
