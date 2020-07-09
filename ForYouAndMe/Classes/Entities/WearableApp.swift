//
//  WearableApp.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 09/07/2020.
//

import Foundation

enum WearableApp: String {
    case oura
    case fitbit
    
    var storeUrl: URL {
        switch self {
        case .oura: return Constants.Url.OuraStoreUrl
        case .fitbit: return Constants.Url.FitbitStoreUrl
        }
    }
    
    var appSchemaUrl: URL {
        switch self {
        case .oura: return Constants.Url.OuraAppSchema
        case .fitbit: return Constants.Url.FitbitAppSchema
        }
    }
}
