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
    case cronometer
    case abbottFreestyleLibre3 = "abbott-freestyle-3"
    case googleHealth = "google_health"

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
        case .cronometer: return Constants.Url.CronometerStoreUrl
        case .abbottFreestyleLibre3: return Constants.Url.AbbottFreestyleLibre3StoreUrl
        case .googleHealth: return Constants.Url.GoogleHealthStoreUrl
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
        case .cronometer: return Constants.Url.CronometerAppSchema
        case .abbottFreestyleLibre3: return Constants.Url.AbbottFreestyleLibre3AppSchema
        case .googleHealth: return Constants.Url.GoogleHealthAppSchema
        }
    }
    
    var apiOAuthUrl: URL {
        if self == .terra {
            var components = URLComponents(url: Constants.Url.ApiOAuthIntegrationBaseUrl.appendingPathComponent(self.rawValue), resolvingAgainstBaseURL: false)
            let locale = Locale.current.languageCode ?? "en"
            components?.queryItems = [URLQueryItem(name: "locale", value: locale)]
            return components?.url ?? Constants.Url.ApiOAuthIntegrationBaseUrl.appendingPathComponent(self.rawValue)
        } else {
            return Constants.Url.ApiOAuthIntegrationBaseUrl.appendingPathComponent(self.rawValue)
        }
    }

    /// FUAM-3418 — variant used by the SFSafariViewController-based Google Health
    /// OAuth flow. SFSafariViewController doesn't share the framework's HTTP
    /// cookie store, so the JWT can't be passed via the `token` cookie the
    /// WKWebView path injects in `ReactiveAuthWebViewController`. Instead we
    /// append it as `?token=Bearer <jwt>` — the backend's
    /// `OmniauthController#authenticate` already reads `params[:token]` as a
    /// fallback to the cookie (`omniauth_controller.rb:7`).
    /// The JWT value is URL-encoded by URLComponents.
    func apiOAuthUrl(withToken jwt: String) -> URL {
        let base = self.apiOAuthUrl
        guard var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            return base
        }
        var queryItems = components.queryItems ?? []
        queryItems.append(URLQueryItem(name: "token", value: "Bearer \(jwt)"))
        components.queryItems = queryItems
        return components.url ?? base
    }

    var apiOAuthDeauthorizeUrl: URL {
        return Constants.Url.ApiOAuthDeauthorizationBaseUrl.appendingPathComponent(self.rawValue)
    }
    
    var strategyPrefix: String {
        return self.rawValue
    }
}
