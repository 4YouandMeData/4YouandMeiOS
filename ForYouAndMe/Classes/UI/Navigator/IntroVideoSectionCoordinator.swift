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
    
    // MARK: - Public Methods
    
    public func getStartingPage() -> UIViewController {
        return IntroVideoViewController(withcoordinator: self)
    }
}

extension IntroVideoSectionCoordinator: IntroViewCoordinator {
    func onIntroVideoCompleted() {
        self.completionCallback(self.navigationController)
    }
}
