//
//  MicrophonePermission.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 16/09/2020.
//

import AVFoundation

struct MicrophonePermission: PermissionProtocol {
    
    var isAuthorized: Bool {
        return AVAudioSession.sharedInstance().recordPermission == .granted
    }
    
    var isDenied: Bool {
        return AVAudioSession.sharedInstance().recordPermission == .denied
    }
    
    func request(completion: @escaping ()->()?) {
        AVAudioSession.sharedInstance().requestRecordPermission {
            granted in
            DispatchQueue.main.async {
                completion()
            }
        }
    }
}
