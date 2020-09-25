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
    
    private let coordinator: WearablePageCoordinator
    private let analytics: AnalyticsService
    private let backwardNavigation: Bool
    
    init(withPage page: Page, coordinator: WearablePageCoordinator, backwardNavigation: Bool) {
        self.page = page
        self.coordinator = coordinator
        self.backwardNavigation = backwardNavigation
        self.analytics = Services.shared.analyticsService
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
        // Bottom View
        let bottomView: UIView = {
            let specialLinkBehavior = self.page.wearablesSpecialLinkBehaviour
            let externalLinkBehavior = self.page.externalLinkUrl
            
            if nil != specialLinkBehavior || nil != externalLinkBehavior {
                let view = DoubleButtonHorizontalView(styleCategory: .secondaryBackground(firstButtonPrimary: true,
                                                                                          secondButtonPrimary: false))
                view.addTargetToSecondButton(target: self, action: #selector(self.primaryButtonPressed))
                let nextButtonText = self.page.buttonSecondlabel ?? StringsProvider.string(forKey: .onboardingWearablesNextButtonDefault)
                view.setSecondButtonText(nextButtonText)
                
                if let specialLinkBehavior = specialLinkBehavior {
                    view.addTargetToFirstButton(target: self, action: #selector(self.specialLinkButtonPressed))
                    let defaultText: String = {
                        switch specialLinkBehavior {
                        case .download: return StringsProvider.string(forKey: .onboardingWearablesDownloadButtonDefault)
                        case .open: return StringsProvider.string(forKey: .onboardingWearablesOpenAppButtonDefault)
                        }
                    }()
                    view.setFirstButtonText(self.page.specialLinkLabel ?? defaultText)
                } else {
                    view.addTargetToFirstButton(target: self, action: #selector(self.externalLinkButtonPressed))
                    let text = self.page.externalLinkLabel ?? StringsProvider.string(forKey: .onboardingWearablesLoginButtonDefault)
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
        self.analytics.track(event: .recordScreen(screenName: self.page.type,
                                                  screenClass: String(describing: type(of: self))))
        self.navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.secondary(hidden: false).style)
        if self.backwardNavigation {
            self.addCustomBackButton()
        } else {
            self.navigationItem.hidesBackButton = true
        }
        
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
