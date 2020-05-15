//
//  CountryCodeProvider.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 15/05/2020.
//

import Foundation

class CountryCodeProvider {
    
    private(set) static var countryCodes: [String] = []
    
    static func initialize(withcountryCodes countryCodes: [String]) {
        self.countryCodes = countryCodes
    }
}
