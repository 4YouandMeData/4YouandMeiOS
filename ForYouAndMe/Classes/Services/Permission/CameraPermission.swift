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
    
    func request(completion: @escaping ()->()?) {
        AVCaptureDevice.requestAccess(for: AVMediaType.video, completionHandler: {
            finished in
            DispatchQueue.main.async {
                completion()
            }
        })
    }
}
