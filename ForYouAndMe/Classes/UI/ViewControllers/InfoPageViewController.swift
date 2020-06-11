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
    let allowBackwardNavigation: Bool
    // TODO: Replace if with info from InfoPage
    let bodyTextAlignment: NSTextAlignment
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
                                           textAlignment: self.pageData.bodyTextAlignment)
        // External Link
        if nil != self.pageData.page.externalLinkUrl, let externalLinkLabel = self.pageData.page.externalLinkLabel {
            scrollStackView.stackView.addBlankSpace(space: 40.0)
            scrollStackView.stackView.addExternalLinkButton(self,
                                                            action: #selector(self.externalLinkButtonPressed),
                                                            text: externalLinkLabel)
        }
        scrollStackView.stackView.addBlankSpace(space: 40.0)
        
        // Confirm Button
        let confirmButtonView: GenericButtonView = {
            if let confirmButtonText = self.pageData.page.buttonFirstlabel {
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
    
    @objc private func confirmButtonPressed() {
        self.coordinator.onInfoPageConfirm(pageData: self.pageData)
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
