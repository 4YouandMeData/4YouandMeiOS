//
//  InfoPageViewController.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 28/05/2020.
//

import Foundation
import PureLayout

public class InfoPageViewController: UIViewController {
    
    private let navigator: AppNavigator
    private let page: Page
    private let addAbortOnboardingButton: Bool
    
    var confirmButtonCallback: ViewControllerCallback?
    
    private lazy var confirmButtonView: GenericButtonView = {
        let view = GenericButtonView(withImageStyleCategory: .secondaryBackground)
        view.button.addTarget(self, action: #selector(self.confirmButtonPressed), for: .touchUpInside)
        return view
    }()
    
    init(withPage page: Page, addAbortOnboardingButton: Bool = false, confirmButtonCallback: ViewControllerCallback? = nil) {
        self.page = page
        self.addAbortOnboardingButton = addAbortOnboardingButton
        self.confirmButtonCallback = confirmButtonCallback
        self.navigator = Services.shared.navigator
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = ColorPalette.color(withType: .secondary)
        
        // ScrollView
        let scrollStackView = ScrollStackView(axis: .vertical, horizontalInset: Constants.Style.DefaultHorizontalMargins)
        self.view.addSubview(scrollStackView)
        scrollStackView.autoPinEdgesToSuperviewSafeArea(with: .zero, excludingEdge: .bottom)
        scrollStackView.stackView.addBlankSpace(space: 132.0)
        scrollStackView.stackView.addHeaderImage(image: self.page.image, height: 54.0)
        scrollStackView.stackView.addBlankSpace(space: 40.0)
        scrollStackView.stackView.addLabel(withText: self.page.title,
                                           fontStyle: .title,
                                           colorType: .primaryText)
        scrollStackView.stackView.addBlankSpace(space: 40.0)
        scrollStackView.stackView.addLabel(withText: self.page.body,
                                           fontStyle: .paragraph,
                                           colorType: .primaryText,
                                           textAlignment: .left)
        self.view.addSubview(self.confirmButtonView)
        self.confirmButtonView.autoPinEdgesToSuperviewSafeArea(with: UIEdgeInsets.zero, excludingEdge: .top)
        
        scrollStackView.scrollView.autoPinEdge(.bottom, to: .top, of: self.confirmButtonView)
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.navigationController?.navigationBar.apply(style: NavigationBarStyles.secondaryStyle)
        self.addCustomBackButton()
        if self.addAbortOnboardingButton {
            self.addOnboardingAbortButton(withColor: ColorPalette.color(withType: .primary))
        }
    }
    
    // MARK: Actions
    
    @objc private func confirmButtonPressed() {
        if let confirmButtonCallback = self.confirmButtonCallback {
            confirmButtonCallback(self)
        } else {
            // TODO: Navigate according to Page navigation data
        }
    }
}
