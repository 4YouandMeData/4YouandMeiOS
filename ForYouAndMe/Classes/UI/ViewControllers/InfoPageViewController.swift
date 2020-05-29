//
//  InfoPageViewController.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 28/05/2020.
//

import Foundation
import PureLayout

protocol InfoPageCoordinator {
    func onInfoPageConfirm(pageData: InfoPageData)
}

struct InfoPageData {
    let page: InfoPage
    let addAbortOnboardingButton: Bool
    let confirmButtonText: String?
    let usePageNavigation: Bool
}

public class InfoPageViewController: UIViewController {
    
    private let navigator: AppNavigator
    private let pageData: InfoPageData
    private let coordinator: InfoPageCoordinator
    
    init(withPageData pageData: InfoPageData, coordinator: InfoPageCoordinator) {
        self.pageData = pageData
        self.coordinator = coordinator
        self.navigator = Services.shared.navigator
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
        
        scrollStackView.stackView.addBlankSpace(space: 132.0)
        // Image
        scrollStackView.stackView.addHeaderImage(image: self.pageData.page.image, height: 54.0)
        scrollStackView.stackView.addBlankSpace(space: 40.0)
        // Title
        scrollStackView.stackView.addLabel(withText: self.pageData.page.title,
                                           fontStyle: .title,
                                           colorType: .primaryText)
        scrollStackView.stackView.addBlankSpace(space: 40.0)
        // Body
        scrollStackView.stackView.addLabel(withText: self.pageData.page.body,
                                           fontStyle: .paragraph,
                                           colorType: .primaryText,
                                           textAlignment: .left)
        // Confirm Button
        let confirmButtonView: GenericButtonView = {
            if let confirmButtonText = self.pageData.confirmButtonText {
                let view = GenericButtonView(withTextStyleCategory: .secondaryBackground)
                view.button.setTitle(confirmButtonText, for: .normal)
                return view
            } else {
                return GenericButtonView(withImageStyleCategory: .secondaryBackground)
            }
        }()
        confirmButtonView.button.addTarget(self, action: #selector(self.confirmButtonPressed), for: .touchUpInside)
        self.view.addSubview(confirmButtonView)
        confirmButtonView.autoPinEdgesToSuperviewSafeArea(with: UIEdgeInsets.zero, excludingEdge: .top)
        scrollStackView.scrollView.autoPinEdge(.bottom, to: .top, of: confirmButtonView)
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.navigationController?.navigationBar.apply(style: NavigationBarStyles.secondaryStyle)
        self.addCustomBackButton()
        if self.pageData.addAbortOnboardingButton {
            self.addOnboardingAbortButton(withColor: ColorPalette.color(withType: .primary))
        }
    }
    
    // MARK: Actions
    
    @objc private func confirmButtonPressed() {
        if self.pageData.usePageNavigation {
            // TODO: Navigate according to Page navigation data
            assertionFailure("Missing link to next page in Page data")
        } else {
            self.coordinator.onInfoPageConfirm(pageData: self.pageData)
        }
    }
}
