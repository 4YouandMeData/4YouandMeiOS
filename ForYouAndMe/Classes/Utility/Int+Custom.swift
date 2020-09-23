//
//  Int+Custom.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 23/09/2020.
//

import Foundation

extension Int {
    
    func formatCount() -> String {
        let number = Double(self)
        let thousand = number / 1000
        let million = number / 1000000
        let billion = number / 1000000000
        
        if billion >= 1.0 {
            return "\(Int(round(billion)))B"
        } else if million >= 1.0 {
            return "\(Int(round(million)))M"
        } else if thousand >= 1.0 {
            return ("\(Int(round(thousand)))k")
        } else {
            return "\(Int(number))"
        }
    }
    
    /// Returns number of digits in Int number
    public var digitCount: Int {
        return numberOfDigits(in: self)
    }
    
    /// Recursive method for counting digits
    private func numberOfDigits(in number: Int) -> Int {
        guard (number < 10 && number >= 0) || (number > -10 && number < 0) else { return 1 + numberOfDigits(in: number / 10) }
        
        return 1
    }
}
