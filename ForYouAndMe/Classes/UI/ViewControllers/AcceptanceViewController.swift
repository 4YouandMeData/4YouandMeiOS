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

struct AcceptanceData {
    let title: String
    let subtitle: String?
    let body: String
    let startingPage: InfoPage
    let pages: [InfoPage]
}

public class AcceptanceViewController: UIViewController {
    
    private let data: AcceptanceData
    
    private let coordinator: AcceptanceCoordinator
    
    init(withData data: AcceptanceData, coordinator: AcceptanceCoordinator) {
        self.data = data
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
        
        scrollStackView.stackView.addLabel(withText: self.data.title,
                                           fontStyle: .title,
                                           colorType: .primaryText,
                                           textAlignment: .left)
        scrollStackView.stackView.addBlankSpace(space: 21.0)
        scrollStackView.stackView.addLabel(withText: self.data.body,
                                           fontStyle: .paragraph,
                                           colorType: .fourthText,
                                           textAlignment: .left)
        if let subtitle = self.data.subtitle, false == subtitle.isEmpty {
            scrollStackView.stackView.addBlankSpace(space: 45.0)
            scrollStackView.stackView.addLabel(withText: subtitle,
                                               fontStyle: .title,
                                               colorType: .primaryText,
                                               textAlignment: .left)
        }
        
        scrollStackView.stackView.addBlankSpace(space: 21.0)
        
        var nextPage: InfoPage? = self.data.startingPage
        while let currentPage = nextPage {
            scrollStackView.stackView.addPage(currentPage)
            scrollStackView.stackView.addBlankSpace(space: 40.0)
            nextPage = currentPage.buttonFirstPage?.getInfoPage(fromInfoPages: self.data.pages)
        }
        
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
        self.navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.secondary(hidden: true).style)
    }
    
    // MARK: Actions
    
    @objc private func agreenButtonPressed() {
        self.coordinator.onAgreeButtonPressed()
    }
    
    @objc private func disagreeButtonPressed() {
        self.coordinator.onDisagreeButtonPressed()
    }
}

fileprivate extension UIStackView {
    
    func addPage(_ page: InfoPage) {
        let view = UIView()
        view.backgroundColor = ColorPalette.color(withType: .inactive)
        view.round(radius: 8.0)
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        view.addSubview(stackView)
        stackView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 40.0, left: 12.0, bottom: 40.0, right: 12.0))
        
        stackView.addLabel(withText: page.title,
                           fontStyle: .header2,
                           colorType: .primaryText,
                           textAlignment: .left)
        stackView.addBlankSpace(space: 21.0)
        stackView.addLabel(withText: page.body,
                           fontStyle: .paragraph,
                           colorType: .primaryText,
                           textAlignment: .left)
        
        self.addArrangedSubview(view)
    }
}
