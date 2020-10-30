//
//  ActivitySectionViewController.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 30/10/2020.
//

import UIKit
import PureLayout

class ActivitySectionViewController: UIViewController {
    
    private let coordinator: ActivitySectionCoordinator
    
    weak var internalNavigationController: UINavigationController?
    
    init(coordinator: ActivitySectionCoordinator, startingViewController: UIViewController) {
        self.coordinator = coordinator
        super.init(nibName: nil, bundle: nil)
        
        let navigationController = UINavigationController(rootViewController: startingViewController)
        self.internalNavigationController = navigationController
        self.addChild(navigationController)
        self.view.addSubview(navigationController.view)
        navigationController.view.autoPinEdgesToSuperviewEdges()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
