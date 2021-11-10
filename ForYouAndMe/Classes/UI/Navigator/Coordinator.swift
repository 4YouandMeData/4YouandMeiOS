//
//  Coordinator.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 19/11/2020.
//

import UIKit

protocol Coordinator {
    func getStartingPage() -> UIViewController
    var hidesBottomBarWhenPushed: Bool { get set }
}
