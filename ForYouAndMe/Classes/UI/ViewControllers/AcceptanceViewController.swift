//
//  AcceptanceViewController.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 18/06/2020.
//

import Foundation
import PureLayout

protocol AcceptanceCoordinator {
    func onAgreeButtonPressed()
    func onDisagreeButtonPressed()
}

public class AcceptanceViewController: UIViewController {
    
    private let startingPage: InfoPage
    private let pages: [InfoPage]
    
    private let coordinator: AcceptanceCoordinator
    
    init(withStartingPage startingPage: InfoPage, pages: [InfoPage], coordinator: AcceptanceCoordinator) {
        self.startingPage = startingPage
        self.pages = pages
        self.coordinator = coordinator
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = ColorPalette.color(withType: .secondary)
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar.apply(style: NavigationBarStyles.hiddenStyle)
    }
    
    // MARK: Actions
    
    @objc private func agreenButtonPressed() {
        self.coordinator.onAgreeButtonPressed()
    }
    
    @objc private func disagreeButtonPressed() {
        self.coordinator.onDisagreeButtonPressed()
    }
}
