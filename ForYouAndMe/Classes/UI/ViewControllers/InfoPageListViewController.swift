//
//  InfoPageListViewController.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 18/06/2020.
//

import Foundation
import PureLayout

enum InfoPageListMode {
    case acceptance(coordinator: AcceptanceCoordinator)
    case view
}

protocol AcceptanceCoordinator {
    func onAgreeButtonPressed()
    func onDisagreeButtonPressed()
}

struct InfoPageListData {
    let title: String
    let subtitle: String?
    let body: String
    let startingPage: Page
    let pages: [Page]
    let mode: InfoPageListMode
}

class InfoPageListViewController: UIViewController {
    
    private let data: InfoPageListData
    
    private let analytics: AnalyticsService
    
    init(withData data: InfoPageListData) {
        self.data = data
        self.analytics = Services.shared.analytics
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = ColorPalette.color(withType: .secondary)
        
        let rootStackView = UIStackView.create(withAxis: .vertical)
        self.view.addSubview(rootStackView)
        rootStackView.autoPinEdgesToSuperviewSafeArea()
        
        // ScrollStackView
        let scrollStackView = ScrollStackView(axis: .vertical, horizontalInset: Constants.Style.DefaultHorizontalMargins)
        rootStackView.addArrangedSubview(scrollStackView)
        
        switch self.data.mode {
        case .acceptance:
            scrollStackView.stackView.addBlankSpace(space: 50.0)
            scrollStackView.stackView.addLabel(withText: self.data.title,
                                               fontStyle: .title,
                                               colorType: .primaryText,
                                               textAlignment: .left)
            scrollStackView.stackView.addBlankSpace(space: 21.0)
            scrollStackView.stackView.addHTMLTextView(withText: self.data.body,
                                               fontStyle: .paragraph,
                                               colorType: .fourthText,
                                               textAlignment: .left)
        case .view:
            break
        }
        
        if let subtitle = self.data.subtitle, false == subtitle.isEmpty {
            scrollStackView.stackView.addBlankSpace(space: 45.0)
            scrollStackView.stackView.addLabel(withText: subtitle,
                                               fontStyle: .title,
                                               colorType: .primaryText,
                                               textAlignment: .left)
        }
        
        scrollStackView.stackView.addBlankSpace(space: 21.0)
        
        var nextPage: Page? = self.data.startingPage
        while let currentPage = nextPage {
            scrollStackView.stackView.addPage(currentPage)
            scrollStackView.stackView.addBlankSpace(space: 40.0)
            nextPage = currentPage.buttonFirstPage?.getPage(fromPages: self.data.pages)
        }
        
        // Bottom View
        switch self.data.mode {
        case .acceptance:
            let bottomView = DoubleButtonHorizontalView(styleCategory: .secondaryBackground(firstButtonPrimary: false,
                                                                                            secondButtonPrimary: true))
            
            bottomView.setFirstButtonText(StringsProvider.string(forKey: .onboardingDisagreeButton))
            bottomView.addTargetToFirstButton(target: self, action: #selector(self.disagreeButtonPressed))
            
            bottomView.setSecondButtonText(StringsProvider.string(forKey: .onboardingAgreeButton))
            bottomView.addTargetToSecondButton(target: self, action: #selector(self.agreenButtonPressed))
                    
            rootStackView.addArrangedSubview(bottomView)
        case .view:
            break
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        switch self.data.mode {
        case .acceptance:
            self.navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.secondary(hidden: true).style)
        case .view:
            self.navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.primary(hidden: false).style)
            self.addCustomBackButton()
        }
        self.analytics.track(event: .recordScreen(screenName: self.data.title,
                                                         screenClass: String(describing: type(of: self))))
    }
    
    // MARK: - Actions
    
    @objc private func agreenButtonPressed() {
        switch self.data.mode {
        case .acceptance(let coordinator):
            coordinator.onAgreeButtonPressed()
        case .view:
            break
        }
    }
    
    @objc private func disagreeButtonPressed() {
        switch self.data.mode {
        case .acceptance(let coordinator):
            coordinator.onDisagreeButtonPressed()
        case .view:
            break
        }
    }
}

fileprivate extension UIStackView {
    
    func addPage(_ page: Page) {
        let view = UIView()
        view.backgroundColor = ColorPalette.color(withType: .secondaryBackgroungColor)
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
        stackView.addHTMLTextView(withText: page.body,
                           fontStyle: .paragraph,
                           colorType: .primaryText,
                           textAlignment: .left)
        
        self.addArrangedSubview(view)
    }
}
