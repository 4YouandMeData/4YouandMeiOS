//
//  CacheManager.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 24/04/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import Foundation

class CacheManager: CacheService {
    
    enum CacheManagerKey: String {
        case globalConfig
        case accessToken
        case deviceUDID
        case userKey
        case firebaseToken
    }
    
    private let mainUserDefaults = UserDefaults.standard
    
    //Protocol
    var user: User? {
        get {return self.load(forKey: CacheManagerKey.userKey.rawValue)}
        set {self.save(encodable: newValue, forKey: CacheManagerKey.userKey.rawValue)}
    }
    
    var deviceUDID: String? {
        get {
            var UDID = self.getString(forKey: CacheManagerKey.deviceUDID.rawValue)
            if UDID == nil || UDID?.isEmpty == true {
                UDID = UIDevice.current.identifierForVendor?.uuidString
                if let deviceUDID = UDID {
                    self.saveString(deviceUDID, forKey: CacheManagerKey.deviceUDID.rawValue)
                }
            }
            return UDID ?? ""
        }
        set {
            self.saveString(newValue, forKey: CacheManagerKey.deviceUDID.rawValue)
        }
    }
    
    var firebaseToken: String? {
        get {return self.load(forKey: CacheManagerKey.firebaseToken.rawValue)}
        set {self.save(encodable: newValue, forKey: CacheManagerKey.firebaseToken.rawValue)}
    }
        
    // MARK: - Private methods
    
    private func save<T>(encodable: T?, forKey key: String) where T: Encodable {
        if let encodable = encodable {
            let encoder = JSONEncoder()
            if let encoded = try? encoder.encode(encodable) {
                self.mainUserDefaults.set(encoded, forKey: key)
            }
        } else {
            self.reset(forKey: key)
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
    
    private func saveString(_ value: String?, forKey key: String) {
        if let value = value {
            self.mainUserDefaults.set(value, forKey: key)
        } else {
            self.reset(forKey: key)
        }
    }
    
    private func getString(forKey key: String) -> String? {
        return self.mainUserDefaults.string(forKey: key)
    }
    
    private func reset(forKey key: String) {
        self.mainUserDefaults.removeObject(forKey: key)
    }
}

// MARK: - RepositoryStorage

extension CacheManager: RepositoryStorage {
    
    var globalConfig: GlobalConfig? {
        get { self.load(forKey: CacheManagerKey.globalConfig.rawValue) }
        set { self.save(encodable: newValue, forKey: CacheManagerKey.globalConfig.rawValue) }
    }
}

// MARK: - NetworkStorage

extension CacheManager: NetworkStorage {
    
    var accessToken: String? {
        get { self.getString(forKey: CacheManagerKey.accessToken.rawValue) }
        set { self.saveString(newValue, forKey: CacheManagerKey.accessToken.rawValue) }
    }
}
