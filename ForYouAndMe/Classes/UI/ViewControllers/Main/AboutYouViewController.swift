//
//  AboutYouViewController.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 11/09/2020.
//

import UIKit

class AboutYouViewController: UIViewController {
    
    private let navigator: AppNavigator

    private lazy var scrollStackView: ScrollStackView = {
        let scrollStackView = ScrollStackView(axis: .vertical, horizontalInset: 0.0)
        return scrollStackView
    }()
    
    init() {
       self.navigator = Services.shared.navigator
       super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
           fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = ColorPalette.color(withType: .secondary)
        
        // Header View
        let headerView = AboutYouHeaderView()
        self.view.addSubview(headerView)
        headerView.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .bottom)
        headerView.closeButton.addTarget(self, action: #selector(self.closeButtonDidPressed), for: .touchUpInside)
        // ScrollStackView
        self.view.addSubview(self.scrollStackView)
        self.scrollStackView.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .top)
        self.scrollStackView.autoPinEdge(.top, to: .bottom, of: headerView, withOffset: 30)
        
        let yourPregnancy = GenericListItemView(withTitle: "Your Pregnancy"/*StringsProvider.string(forKey: .studyInfoContactItem)*/,
            templateImageName: .pregnancyIcon,
            colorType: .primary,
            gestureCallback: { [weak self] in
                let page = Page(id: "contact", title: "Contact", body: Constants.Test.LoremIpsum)
                self?.showPage(page: page, isModal: false)
        })
        self.scrollStackView.stackView.addArrangedSubview(yourPregnancy)
        
        let appsAndDevices = GenericListItemView(withTitle: "Your Apps & Devices"/*StringsProvider.string(forKey: .studyInfoRewardsItem)*/,
            templateImageName: .devicesIcon,
            colorType: .primary,
            gestureCallback: { [weak self] in
                let page = Page(id: "rewards", title: "Rewards", body: Constants.Test.LoremIpsum)
                self?.showPage(page: page, isModal: false)
        })
        self.scrollStackView.stackView.addArrangedSubview(appsAndDevices)
        
        self.scrollStackView.stackView.addLineSeparator(lineColor: ColorPalette.color(withType: .inactive),
                                                        horizontalInset: 21)
        
        let reviewConsent = GenericListItemView(withTitle: "Review Consent"/*StringsProvider.string(forKey: .studyInfoFaqItem)*/,
            templateImageName: .reviewConsentIcon,
            colorType: .primary,
            gestureCallback: { [weak self] in
                let page = Page(id: "faq", title: "FAQ", body: Constants.Test.LoremIpsum)
                self?.showPage(page: page, isModal: false)
        })
        self.scrollStackView.stackView.addArrangedSubview(reviewConsent)
        
        let permissions = GenericListItemView(withTitle: "Permissions"/*StringsProvider.string(forKey: .studyInfoFaqItem)*/,
                   templateImageName: .permissionIcon,
                   colorType: .primary,
                   gestureCallback: { [weak self] in
                       let page = Page(id: "faq", title: "FAQ", body: Constants.Test.LoremIpsum)
                       self?.showPage(page: page, isModal: false)
               })
               self.scrollStackView.stackView.addArrangedSubview(permissions)
        
        self.scrollStackView.stackView.addBlankSpace(space: 57)
        self.scrollStackView.stackView.addLabel(withText: "You are currently participating in the BUMP pregnancy research study. If for any reason you no longer wish to continue participating in the study, you can elect to leave this study by contacting the study team.",
                                                fontStyle: .paragraph,
                                                colorType: .fourthText,
                                                textAlignment: .left,
                                                horizontalInset: 21)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.primary(hidden: true).style)
    }
    
    private func showPage(page: Page, isModal: Bool) {
        self.navigator.showInfoDetailPage(presenter: self, page: page, isModal: isModal)
    }
    
    @objc private func closeButtonDidPressed() {
        self.customCloseButtonPressed()
    }
}
