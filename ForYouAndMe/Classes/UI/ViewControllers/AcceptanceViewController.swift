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
        
        // ScrollStackView
        let scrollStackView = ScrollStackView(axis: .vertical, horizontalInset: Constants.Style.DefaultHorizontalMargins)
        self.view.addSubview(scrollStackView)
        scrollStackView.autoPinEdgesToSuperviewSafeArea(with: .zero, excludingEdge: .bottom)
        
        scrollStackView.stackView.addBlankSpace(space: 50.0)
        
        // TODO: Add content
        
        // Bottom View
        let bottomView = DoubleButtonHorizontalView(styleCategory: .secondaryBackground(firstButtonPrimary: false,
                                                                                        secondButtonPrimary: true))
        
        bottomView.setFirstButtonText(StringsProvider.string(forKey: .onboardingDisagreeButton))
        bottomView.addTargetToFirstButton(target: self, action: #selector(self.disagreeButtonPressed))
        
        bottomView.setSecondButtonText(StringsProvider.string(forKey: .onboardingAgreeButton))
        bottomView.addTargetToSecondButton(target: self, action: #selector(self.agreenButtonPressed))
                
        self.view.addSubview(bottomView)
        bottomView.autoPinEdgesToSuperviewSafeArea(with: UIEdgeInsets.zero, excludingEdge: .top)
        scrollStackView.scrollView.autoPinEdge(.bottom, to: .top, of: bottomView)
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
