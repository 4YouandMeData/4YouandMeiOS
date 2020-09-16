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
    
    func request(completion: @escaping ()->()?) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                completion()
            }
        }
    }
}
