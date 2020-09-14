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
                guard let navigationController = self?.navigationController else {
                    assertionFailure("Missing expected navigation controller")
                    return
                }
                // TODO: Replace mock data with data from server
                let title = "Your Pregnancy"/*StringsProvider.string(forKey: .studyInfoContactItem)*/
                let userInfoParameters: [UserInfoParameter] = [
                    UserInfoParameter(identifier: "1",
                                      name: "Your due date",
//                                      value: "",
                                      value: "2020-06-03T12:59:39.083Z",
                                      type: .date,
                                      items: []),
                    UserInfoParameter(identifier: "2",
                                      name: "Your baby's gender",
//                                      value: "",
                                      value: "2",
                                      type: .items,
                                      items: [
                                        UserInfoParameterItem(identifier: "1", value: "It's a Boy!"),
                                        UserInfoParameterItem(identifier: "2", value: "It's a Girl!")
                    ]),
                    UserInfoParameter(identifier: "3",
                                      name: "Your baby's name",
//                                      value: "",
                                      value: "Lil'Pea",
                                      type: .string,
                                      items: [])
                ]
                self?.navigator.showUserInfoPage(navigationController: navigationController,
                                                 title: title,
                                                 userInfoParameters: userInfoParameters)
        })
        self.scrollStackView.stackView.addArrangedSubview(yourPregnancy)
        
        let appsAndDevices = GenericListItemView(withTitle: "Your Apps & Devices"/*StringsProvider.string(forKey: .studyInfoRewardsItem)*/,
            templateImageName: .devicesIcon,
            colorType: .primary,
            gestureCallback: { [weak self] in
                self?.navigator.showAppsAndDevices(navigationController: self?.navigationController ?? UINavigationController(),
                                                   title: "Your Apps & Devices")
        })
        self.scrollStackView.stackView.addArrangedSubview(appsAndDevices)
        
        self.scrollStackView.stackView.addLineSeparator(lineColor: ColorPalette.color(withType: .inactive),
                                                        inset: 21,
                                                        isVertical: false)
        
        let reviewConsent = GenericListItemView(withTitle: "Review Consent"/*StringsProvider.string(forKey: .studyInfoFaqItem)*/,
            templateImageName: .reviewConsentIcon,
            colorType: .primary,
            gestureCallback: { [weak self] in
                self?.navigator.showReviewConsent(navigationController: self?.navigationController ?? UINavigationController())
        })
        self.scrollStackView.stackView.addArrangedSubview(reviewConsent)
        
        let permissions = GenericListItemView(withTitle: "Permissions"/*StringsProvider.string(forKey: .studyInfoFaqItem)*/,
            templateImageName: .permissionIcon,
            colorType: .primary,
            gestureCallback: { [weak self] in
                self?.navigator.showPermissions(navigationController: self?.navigationController ?? UINavigationController(),
                title: "Permissions")
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
