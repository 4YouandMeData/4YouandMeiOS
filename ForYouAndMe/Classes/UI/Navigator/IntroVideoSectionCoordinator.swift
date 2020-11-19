//
//  IntroVideoSectionCoordinator.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 19/11/2020.
//

import UIKit

class IntroVideoSectionCoordinator {
    
    public unowned var navigationController: UINavigationController

    private let completionCallback: NavigationControllerCallback
    
    init(withNavigationController navigationController: UINavigationController,
         completionCallback: @escaping NavigationControllerCallback) {
        self.navigationController = navigationController
        self.completionCallback = completionCallback
    }
}

extension IntroVideoSectionCoordinator: Coordinator {
    func getStartingPage() -> UIViewController {
        return IntroVideoViewController(withCoordinator: self)
    }
}

extension IntroVideoSectionCoordinator: IntroViewCoordinator {
    func onIntroVideoCompleted() {
        self.completionCallback(self.navigationController)
    }
}
