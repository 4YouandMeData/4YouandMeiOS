//
//  Style.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 30/04/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import UIKit

public protocol View {}
extension UIView: View {}

public extension View {
    
    func apply(style: Style<Self>) {
        style.stylize(self)
    }
}

public class Style<T> {
    
    let stylize: ((T) -> Void)
    
    public init(stylize: @escaping (T) -> Void) {
        self.stylize = stylize
    }
}
