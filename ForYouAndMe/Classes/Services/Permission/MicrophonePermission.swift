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
    
    var isNotDetermined: Bool {
        return AVAudioSession.sharedInstance().recordPermission == .undetermined
    }
    
    var isRestricted: Bool {
        return false
    }
    
    func request(completion: @escaping () -> Void?) {
        AVAudioSession.sharedInstance().requestRecordPermission { _ in
            DispatchQueue.main.async {
                completion()
            }
        }
    }
}
