//
//  PageProtocols.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 03/07/2020.
//

import Foundation

protocol PageCoordinator {
    func onPagePrimaryButtonPressed(page: Page)
    func onPageSecondaryButtonPressed(page: Page)
}

protocol PageProvider {
    var page: Page { get }
}
