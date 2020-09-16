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
    
    func request(completion: @escaping () -> Void?) {
        PHPhotoLibrary.requestAuthorization({ _ in
            DispatchQueue.main.async {
                completion()
            }
        })
    }
}
