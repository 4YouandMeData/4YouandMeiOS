//
//  InfoPageViewController.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 28/05/2020.
//

import Foundation
import PureLayout

protocol InfoPageCoordinator {
    func onInfoPagePrimaryButtonPressed(pageData: InfoPageData)
    func onInfoPageSecondaryButtonPressed(pageData: InfoPageData)
}

enum InfoPageBottomViewStyle {
    case singleButton
    case vertical(backButton: Bool)
}

struct InfoPageData {
    let page: InfoPage
    let addAbortOnboardingButton: Bool
    let allowBackwardNavigation: Bool
    // TODO: Replace if with info from InfoPage
    let bodyTextAlignment: NSTextAlignment
    let bottomViewStyle: InfoPageBottomViewStyle
    
    static func createWelcomePageData(withinfoPage infopage: InfoPage) -> InfoPageData {
        return InfoPageData(page: infopage,
                            addAbortOnboardingButton: false,
                            allowBackwardNavigation: false,
                            bodyTextAlignment: .left,
                            bottomViewStyle: .singleButton)
    }
    
    static func createInfoPageData(withinfoPage infopage: InfoPage, isOnboarding: Bool) -> InfoPageData {
        return InfoPageData(page: infopage,
                            addAbortOnboardingButton: isOnboarding,
                            allowBackwardNavigation: true,
                            bodyTextAlignment: .left,
                            bottomViewStyle: .singleButton)
    }
    
    static func createResultPageData(withinfoPage infopage: InfoPage) -> InfoPageData {
        return InfoPageData(page: infopage,
                            addAbortOnboardingButton: false,
                            allowBackwardNavigation: false,
                            bodyTextAlignment: .center,
                            bottomViewStyle: .singleButton)
    }
}

public class InfoPageViewController: UIViewController {
    
    let pageData: InfoPageData
    
    private let navigator: AppNavigator
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
        scrollStackView.stackView.addLabel(withText: self.pageData.page.body,
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
        } else {
            self.navigationItem.hidesBackButton = true
        }
        if self.pageData.addAbortOnboardingButton {
            self.addOnboardingAbortButton(withColor: ColorPalette.color(withType: .gradientPrimaryEnd))
        }
    }
    
    // MARK: Actions
    
    @objc private func primaryButtonPressed() {
        self.coordinator.onInfoPagePrimaryButtonPressed(pageData: self.pageData)
    }
    
    @objc private func secondaryButtonPressed() {
        self.coordinator.onInfoPageSecondaryButtonPressed(pageData: self.pageData)
    }
    
    @objc private func externalLinkButtonPressed() {
        guard let url = self.pageData.page.externalLinkUrl else {
            assertionFailure("Missing expected external link url")
            return
        }
        self.navigator.openWebView(withTitle: "", url: url, presenter: self)
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
