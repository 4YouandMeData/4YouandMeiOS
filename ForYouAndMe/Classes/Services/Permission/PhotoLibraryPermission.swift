//
//  PhotoLibraryPermission.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 16/09/2020.
//

import Photos

struct PhotoLibraryPermission: PermissionProtocol {
    
    var isAuthorized: Bool {
        return PHPhotoLibrary.authorizationStatus() == PHAuthorizationStatus.authorized
    }
    
    var isDenied: Bool {
        return PHPhotoLibrary.authorizationStatus() == PHAuthorizationStatus.denied
    }
    
    var isNotDetermined: Bool {
        return PHPhotoLibrary.authorizationStatus() == PHAuthorizationStatus.notDetermined
    }
    
    var isRestricted: Bool {
        return PHPhotoLibrary.authorizationStatus() == PHAuthorizationStatus.restricted
    }
    
    func request(completion: @escaping () -> Void?) {
        PHPhotoLibrary.requestAuthorization({ _ in
            DispatchQueue.main.async {
                completion()
            }
        })
    }
}
