//
//  CameraPermission.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 16/09/2020.
//

import AVFoundation

struct CameraPermission: PermissionProtocol {
    
    var isAuthorized: Bool {
        return AVCaptureDevice.authorizationStatus(for: AVMediaType.video) == AVAuthorizationStatus.authorized
    }
    
    var isDenied: Bool {
        return AVCaptureDevice.authorizationStatus(for: AVMediaType.video) == AVAuthorizationStatus.denied
    }
    
    var isRestricted: Bool {
        return AVCaptureDevice.authorizationStatus(for: AVMediaType.video) == AVAuthorizationStatus.restricted
    }
    
    var isNotDetermined: Bool {
        return AVCaptureDevice.authorizationStatus(for: AVMediaType.video) == AVAuthorizationStatus.notDetermined
    }
    
    func request(completion: @escaping () -> Void?) {
        AVCaptureDevice.requestAccess(for: AVMediaType.video, completionHandler: { _ in
            DispatchQueue.main.async {
                completion()
            }
        })
    }
}
