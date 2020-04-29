//
//  CacheManager.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 24/04/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import Foundation

class CacheManager {
    
    enum CacheManagerKey: String {
        case globalConfig
    }
    
    private let mainUserDefaults = UserDefaults.standard
    
    // MARK: - Private methods
    
    private func save<T>(encodable: T, forKey key: String) where T: Encodable {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(encodable) {
            self.mainUserDefaults.set(encoded, forKey: key)
        }
    }
    
    private func load<T>(forKey key: String) -> T? where T: Decodable {
        if let encodedData = self.mainUserDefaults.object(forKey: key) as? Data {
            let decoder = JSONDecoder()
            if let object = try? decoder.decode(T.self, from: encodedData) {
                return object
            }
        }
        return nil
    }
    
    private func reset(forKey key: String) {
        self.mainUserDefaults.removeObject(forKey: key)
    }
}

// MARK: - RepositoryStorage

extension CacheManager: RepositoryStorage {
    
    var globalConfig: GlobalConfig? {
        get {
            return self.load(forKey: CacheManagerKey.globalConfig.rawValue)
        }
        set {
            if let value = newValue {
                self.save(encodable: value, forKey: CacheManagerKey.globalConfig.rawValue)
            } else {
                self.reset(forKey: CacheManagerKey.globalConfig.rawValue)
            }
        }
    }
}
