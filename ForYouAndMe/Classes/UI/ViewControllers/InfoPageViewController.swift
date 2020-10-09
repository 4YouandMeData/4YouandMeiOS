//
//  InfoPageViewController.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 28/05/2020.
//

import Foundation
import PureLayout

enum InfoPageBottomViewStyle {
    case singleButton
    case vertical(backButton: Bool)
    case horizontal
}

struct InfoPageData {
    let page: Page
    let addAbortOnboardingButton: Bool
    let addCloseButton: Bool
    let allowBackwardNavigation: Bool
    let bodyTextAlignment: NSTextAlignment
    let bottomViewStyle: InfoPageBottomViewStyle
    
    static func createWelcomePageData(withPage page: Page, showCloseButton: Bool = false) -> InfoPageData {
        return InfoPageData(page: page,
                            addAbortOnboardingButton: false,
                            addCloseButton: showCloseButton,
                            allowBackwardNavigation: false,
                            bodyTextAlignment: .left,
                            bottomViewStyle: .singleButton)
    }
    
    static func createInfoPageData(withPage page: Page, isOnboarding: Bool) -> InfoPageData {
        return InfoPageData(page: page,
                            addAbortOnboardingButton: isOnboarding,
                            addCloseButton: false,
                            allowBackwardNavigation: true,
                            bodyTextAlignment: .left,
                            bottomViewStyle: .singleButton)
    }
    
    static func createResultPageData(withPage page: Page) -> InfoPageData {
        return InfoPageData(page: page,
                            addAbortOnboardingButton: false,
                            addCloseButton: false,
                            allowBackwardNavigation: false,
                            bodyTextAlignment: .center,
                            bottomViewStyle: .singleButton)
    }
}

public class InfoPageViewController: UIViewController, PageProvider {
    
    var page: Page { return self.pageData.page }
    
    private let pageData: InfoPageData
    
    private let navigator: AppNavigator
    private let coordinator: PageCoordinator
    private let analytics: AnalyticsService
    
    init(withPageData pageData: InfoPageData, coordinator: PageCoordinator) {
        self.pageData = pageData
        self.coordinator = coordinator
        self.navigator = Services.shared.navigator
        self.analytics = Services.shared.analytics
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
        // Image
        scrollStackView.stackView.addHeaderImage(image: self.pageData.page.image, height: 54.0)
        scrollStackView.stackView.addBlankSpace(space: 40.0)
        // Title
        scrollStackView.stackView.addLabel(withText: self.pageData.page.title,
                                           fontStyle: .title,
                                           colorType: .primaryText)
        
        scrollStackView.stackView.addBlankSpace(space: 40.0)
        // Body
        scrollStackView.stackView.addHTMLTextView(withText: self.pageData.page.body,
                                           fontStyle: .paragraph,
                                           colorType: .primaryText,
                                           textAlignment: self.pageData.bodyTextAlignment)
        // External Link
        if nil != self.pageData.page.externalLinkUrl, let externalLinkLabel = self.pageData.page.externalLinkLabel {
            scrollStackView.stackView.addBlankSpace(space: 40.0)
            scrollStackView.stackView.addExternalLinkButton(self,
                                                            action: #selector(self.externalLinkButtonPressed),
                                                            text: externalLinkLabel)
        }
        if nil != self.pageData.page.linkModalPage, let linkModalLabel = self.pageData.page.linkModalLabel {
            scrollStackView.stackView.addBlankSpace(space: 40.0)
            scrollStackView.stackView.addExternalLinkButton(self,
                                                            action: #selector(self.modalLinkButtonPressed),
                                                            text: linkModalLabel)
        }
        scrollStackView.stackView.addBlankSpace(space: 40.0)
        
        // Bottom View
        let bottomView: UIView = {
            switch self.pageData.bottomViewStyle {
            case .singleButton:
                let view: GenericButtonView = {
                    if let confirmButtonText = self.pageData.page.buttonFirstlabel {
                        let view = GenericButtonView(withTextStyleCategory: .secondaryBackground())
                        view.setButtonText(confirmButtonText)
                        return view
                    } else {
                        return GenericButtonView(withImageStyleCategory: .secondaryBackground)
                    }
                }()
                view.addTarget(target: self, action: #selector(self.primaryButtonPressed))
                return view
            case .vertical(let backButton):
                let view = DoubleButtonVerticalView(styleCategory: .secondaryBackground(backButton: backButton))
                view.addTargetToPrimaryButton(target: self, action: #selector(self.primaryButtonPressed))
                if let buttonSecondlabel = self.pageData.page.buttonSecondlabel {
                    view.addTargetToSecondaryButton(target: self, action: #selector(self.secondaryButtonPressed))
                    view.setSecondaryButtonText(buttonSecondlabel)
                }
                return view
            case .horizontal:
                if let buttonFirstlabel = self.pageData.page.buttonFirstlabel,
                   let buttonSecondlabel = self.pageData.page.buttonSecondlabel {
                    let view = DoubleButtonHorizontalView(styleCategory: .secondaryBackground(firstButtonPrimary: false,
                                                                                              secondButtonPrimary: true))
                    view.addTargetToFirstButton(target: self, action: #selector(self.secondaryButtonPressed))
                    view.addTargetToSecondButton(target: self, action: #selector(self.primaryButtonPressed))
                    view.setFirstButtonText(buttonSecondlabel)
                    view.setSecondButtonText(buttonFirstlabel)
                    return view
                } else {
                    let view: GenericButtonView = {
                        if let confirmButtonText = self.pageData.page.buttonFirstlabel {
                            let view = GenericButtonView(withTextStyleCategory: .secondaryBackground())
                            view.setButtonText(confirmButtonText)
                            return view
                        } else {
                            return GenericButtonView(withImageStyleCategory: .secondaryBackground)
                        }
                    }()
                    view.addTarget(target: self, action: #selector(self.primaryButtonPressed))
                    return view
                }
            }
        }()
        self.view.addSubview(bottomView)
        bottomView.autoPinEdgesToSuperviewSafeArea(with: UIEdgeInsets.zero, excludingEdge: .top)
        scrollStackView.scrollView.autoPinEdge(.bottom, to: .top, of: bottomView)
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.secondary(hidden: false).style)
        if self.pageData.allowBackwardNavigation {
            self.addCustomBackButton()
        } else if self.pageData.addCloseButton {
            self.addCustomCloseButton()
        } else {
            self.navigationItem.hidesBackButton = true
        }
        if self.pageData.addAbortOnboardingButton {
            self.addOnboardingAbortButton(withColor: ColorPalette.color(withType: .gradientPrimaryEnd))
        }
    }
    
    // MARK: Actions
    
    @objc private func primaryButtonPressed() {
        self.coordinator.onPagePrimaryButtonPressed(page: self.pageData.page)
    }
    
    @objc private func secondaryButtonPressed() {
        self.coordinator.onPageSecondaryButtonPressed(page: self.pageData.page)
    }
    
    @objc private func externalLinkButtonPressed() {
        guard let url = self.pageData.page.externalLinkUrl else {
            assertionFailure("Missing expected external link url")
            return
        }
        
        self.analytics.track(event: .recordScreen(screenName: AnalyticsScreens.learnMore.rawValue,
                                                  screenClass: String(describing: type(of: self))))
        self.navigator.openWebView(withTitle: "", url: url, presenter: self)
    }
    
    @objc private func modalLinkButtonPressed() {
        guard let linkedPageRef = self.pageData.page.linkModalPage else {
            assertionFailure("Missing expected modal link page ref")
            return
        }
        self.coordinator.onLinkedPageButtonPressed(modalPageRef: linkedPageRef)
    }
}

fileprivate extension UIStackView {
    func addExternalLinkButton(_ target: Any?, action: Selector, text: String) {
        let button = UIButton()
        button.setTitle(text, for: .normal)
        button.setTitleColor(ColorPalette.color(withType: .gradientPrimaryEnd), for: .normal)
        button.titleLabel?.font = FontPalette.fontStyleData(forStyle: .paragraph).font
        button.addTarget(target, action: action, for: .touchUpInside)
        let buttonContainerView = UIView()
        buttonContainerView.addSubview(button)
        button.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .trailing)
        button.autoPinEdge(toSuperviewEdge: .trailing, withInset: 0.0, relation: .greaterThanOrEqual)
        button.autoSetDimension(.height, toSize: 44.0)
        self.addArrangedSubview(buttonContainerView)
    }
}
