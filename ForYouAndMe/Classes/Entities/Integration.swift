//
//  Integration.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 09/07/2020.
//

import Foundation

public enum Integration: String {
    case oura
    case fitbit
    case garmin
    case instagram
    case rescueTime = "rescuetime"
    case twitter
    case dexcom
    case terra
    case empatica
    
    var storeUrl: URL {
        switch self {
        case .oura: return Constants.Url.OuraStoreUrl
        case .fitbit: return Constants.Url.FitbitStoreUrl
        case .garmin: return Constants.Url.GarminStoreUrl
        case .instagram: return Constants.Url.InstagramStoreUrl
        case .rescueTime: return Constants.Url.RescueTimeStoreUrl
        case .twitter: return Constants.Url.TwitterStoreUrl
        case .dexcom: return Constants.Url.DexComStoreUrl
        case .terra: return Constants.Url.TerraStoreUrl
        case .empatica: return Constants.Url.EmpaticaStoreUrl
        }
    }
    
    var appSchemaUrl: URL {
        switch self {
        case .oura: return Constants.Url.OuraAppSchema
        case .fitbit: return Constants.Url.FitbitAppSchema
        case .garmin: return Constants.Url.GarminAppSchema
        case .instagram: return Constants.Url.InstagramAppSchema
        case .rescueTime: return Constants.Url.RescueTimeAppSchema
        case .twitter: return Constants.Url.TwitterAppSchema
        case .dexcom: return Constants.Url.DexComAppSchema
        case .terra: return Constants.Url.TerraAppSchema
        case .empatica: return Constants.Url.EmpaticaAppSchema
        }
    }
    
    var apiOAuthUrl: URL {
        return Constants.Url.ApiOAuthIntegrationBaseUrl.appendingPathComponent(self.rawValue)
    }
    
    var apiOAuthDeauthorizeUrl: URL {
        return Constants.Url.ApiOAuthDeauthorizationBaseUrl.appendingPathComponent(self.rawValue)
    }
    
    var strategyPrefix: String {
        return self.rawValue
    }
}
