//
//  PageProtocols.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 03/07/2020.
//

import Foundation

protocol PageCoordinator: Coordinator {
    func onPagePrimaryButtonPressed(page: Page)
    func onPageSecondaryButtonPressed(page: Page)
    func onLinkedPageButtonPressed(modalPageRef: PageRef)
}

protocol PageProvider {
    var page: Page { get }
}
