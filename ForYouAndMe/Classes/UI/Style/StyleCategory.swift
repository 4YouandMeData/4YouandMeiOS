//
//  StyleCategory.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 11/06/2020.
//

import UIKit

protocol StyleCategory {
    associatedtype View
    var style: Style<View> { get }
}
