//
//  SpeechPermission.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 16/09/2020.
//

import Speech

struct SpeechPermission: PermissionProtocol {
    
    var isAuthorized: Bool {
        return SFSpeechRecognizer.authorizationStatus() == .authorized
    }
    
    var isDenied: Bool {
        return SFSpeechRecognizer.authorizationStatus() == .denied
    }
    
    var isNotDetermined: Bool {
        return SFSpeechRecognizer.authorizationStatus() == .notDetermined
    }
    
    var isRestricted: Bool {
        return SFSpeechRecognizer.authorizationStatus() == .restricted
    }
    
    func request(completion: @escaping ()->()?) {
        SFSpeechRecognizer.requestAuthorization { _ in
            DispatchQueue.main.async {
                completion()
            }
        }
    }
}
