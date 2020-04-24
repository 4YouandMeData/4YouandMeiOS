//
//  NetworkUtility.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 24/04/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import Foundation

public extension String {
    var urlEscaped: String {
        return self.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
    }
    
    var utf8Encoded: Data {
        return self.data(using: .utf8)!
    }
}
public extension Optional where Wrapped == Int {
    var toString: String {
        return self != nil ? String(describing: self) : ""
    }
}

public extension Int {
    var toString: String {
        return String(describing: self)
    }
}

public extension Bundle {
    static func getTestData(from fileName: String) -> Data {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "json"),
            let data = try? Data(contentsOf: url) else {
                return Data()
        }
        return data
    }
}

public extension Data {
    static func JSONResponseDataFormatter(_ data: Data) -> String {
        return JSONPrettyDataFormatter(data)
    }
    
    static func JSONRequestDataFormatter(_ data: Data) -> String {
        return JSONPrettyDataFormatter(data)
    }
    
    private static func JSONPrettyDataFormatter(_ data: Data) -> String {
        do {
            let dataAsJSON = try JSONSerialization.jsonObject(with: data)
            let prettyData =  try JSONSerialization.data(withJSONObject: dataAsJSON, options: .prettyPrinted)
            return String(data: prettyData, encoding: .utf8) ?? ""
        } catch {
            return String(data: data, encoding: .utf8) ?? ""
        }
    }
}
