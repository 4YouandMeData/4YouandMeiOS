//
//  AudioAssetManager.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 23/12/24.
//

import AVFoundation

protocol AudioAssetManagerProtocol {
    func fetchAudioDuration(from url: URL, completion: @escaping (TimeInterval?) -> Void)
}

class AudioAssetManager: AudioAssetManagerProtocol {
    
    func fetchAudioDuration(from url: URL, completion: @escaping (TimeInterval?) -> Void) {
        let asset = AVURLAsset(url: url)
        asset.loadValuesAsynchronously(forKeys: ["duration"]) {
            DispatchQueue.main.async {
                var error: NSError?
                let status = asset.statusOfValue(forKey: "duration", error: &error)
                switch status {
                case .loaded:
                    let duration = CMTimeGetSeconds(asset.duration)
                    if duration.isFinite {
                        completion(duration)
                    } else {
                        completion(nil)
                    }
                case .failed, .cancelled:
                    print("Failed to load duration: \(String(describing: error?.localizedDescription))")
                    completion(nil)
                default:
                    completion(nil)
                }
            }
        }
    }
}
