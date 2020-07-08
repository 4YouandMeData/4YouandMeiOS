//
//  WearablePageViewController.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 03/07/2020.
//

import Foundation
import PureLayout

protocol WearablePageCoordinator: PageCoordinator {
    func onWearablePageExternalLinkButtonPressed(page: Page)
    func onWearablePageSpecialLinkButtonPressed(page: Page)
}

public class WearablePageViewController: UIViewController, PageProvider {
    
    var page: Page
    
    private let navigator: AppNavigator
    private let coordinator: WearablePageCoordinator
    
    init(withPage page: Page, coordinator: WearablePageCoordinator) {
        self.page = page
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
        
        scrollStackView.stackView.addBlankSpace(space: 130.0)
        // Title
        scrollStackView.stackView.addLabel(withText: self.page.title,
                                           fontStyle: .title,
                                           colorType: .primaryText,
                                           textAlignment: .left)
        scrollStackView.stackView.addBlankSpace(space: 40.0)
        // Body
        scrollStackView.stackView.addLabel(withText: self.page.body,
                                           fontStyle: .paragraph,
                                           colorType: .primaryText,
                                           textAlignment: .left)
        // External Link
        
        // Bottom View
        let bottomView: UIView = {
            let specialLinkBehavior = PageSpecialLinkType.app == self.page.specialLinkType && self.page.specialLinkValue != nil
            let hasExternalLinkBehavior = self.page.externalLinkUrl != nil
            
            if specialLinkBehavior || hasExternalLinkBehavior {
                let view = DoubleButtonHorizontalView(styleCategory: .secondaryBackground(firstButtonPrimary: true,
                                                                                          secondButtonPrimary: false))
                view.addTargetToSecondButton(target: self, action: #selector(self.primaryButtonPressed))
                let nextButtonText = self.page.buttonSecondlabel ?? StringsProvider.string(forKey: .onboardingWearablesNextButtonDefault)
                view.setSecondButtonText(nextButtonText)
                
                if specialLinkBehavior {
                    view.addTargetToFirstButton(target: self, action: #selector(self.specialLinkButtonPressed))
                    guard let text = self.page.specialLinkLabel else {
                        assertionFailure("Missing special link label for expected special link behviour")
                        view.setFirstButtonText("")
                        return view
                    }
                    view.setFirstButtonText(text)
                } else {
                    view.addTargetToFirstButton(target: self, action: #selector(self.externalLinkButtonPressed))
                    guard let text = self.page.externalLinkLabel else {
                        assertionFailure("Missing special link label for expected external link behviour")
                        view.setFirstButtonText("")
                        return view
                    }
                    view.setFirstButtonText(text)
                }
                
                return view
            } else {
                let view = GenericButtonView(withImageStyleCategory: .secondaryBackground)
                view.addTarget(target: self, action: #selector(self.primaryButtonPressed))
                return view
            }
        }()
        self.view.addSubview(bottomView)
        bottomView.autoPinEdgesToSuperviewSafeArea(with: UIEdgeInsets.zero, excludingEdge: .top)
        scrollStackView.scrollView.autoPinEdge(.bottom, to: .top, of: bottomView)
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.secondary(hidden: false).style)
        self.addCustomBackButton()
    }
    
    // MARK: Actions
    
    @objc private func primaryButtonPressed() {
        self.coordinator.onPagePrimaryButtonPressed(page: self.page)
    }
    
    @objc private func externalLinkButtonPressed() {
        self.coordinator.onWearablePageExternalLinkButtonPressed(page: self.page)
    }
    
    @objc private func specialLinkButtonPressed() {
        self.coordinator.onWearablePageSpecialLinkButtonPressed(page: self.page)
    }
}
