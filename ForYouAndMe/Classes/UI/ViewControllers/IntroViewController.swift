//
//  IntroViewController.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 30/04/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import Foundation
import PureLayout

public class IntroViewController: UIViewController {
    
    private let navigator: AppNavigator
    
    private lazy var backButton: UIButton = {
        let button = UIButton()
        button.setImage(ImagePalette.image(withName: .nextButtonLight), for: .normal)
        button.addTarget(self, action: #selector(self.backButtonPressed), for: .touchUpInside)
        return button
    }()
    
    private lazy var loginButton: UIButton = {
        let button = UIButton()
        button.setImage(ImagePalette.image(withName: .nextButtonLight), for: .normal)
        button.addTarget(self, action: #selector(self.showLogin), for: .touchUpInside)
        return button
    }()
    
    init() {
        self.navigator = Services.shared.navigator
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.addGradientView(GradientView(type: .defaultBackground))
        
        // ScrollView
        let scrollView = UIScrollView()
        scrollView.contentInsetAdjustmentBehavior = .never
        self.view.addSubview(scrollView)
        scrollView.autoPinEdgesToSuperviewSafeArea(with: UIEdgeInsets.zero, excludingEdge: .bottom)
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        scrollView.addSubview(stackView)
        stackView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 16.0,
                                                                  left: Constants.Style.DefaultHorizontalMargins,
                                                                  bottom: 16.0,
                                                                  right: Constants.Style.DefaultHorizontalMargins))
        stackView.autoAlignAxis(toSuperviewAxis: .vertical)
        
        stackView.addHeaderImage(image: ImagePalette.image(withName: .fyamLogo))
        stackView.addBlankSpace(space: 50.0)
        stackView.addLabel(text: StringsProvider.string(forKey: .introTitle),
                           font: FontPalette.font(withSize: 23.0),
                           textColor: ColorPalette.color(withType: .secondaryText),
                           textAlignment: .left)
        stackView.addBlankSpace(space: 40.0)
        stackView.addLabel(text: StringsProvider.string(forKey: .introBody),
                           font: FontPalette.font(withSize: 16.0),
                           textColor: ColorPalette.color(withType: .secondaryText),
                           textAlignment: .left,
                           lineSpacing: 10.0)
        
        let bottomStackView = UIStackView()
        bottomStackView.axis = .vertical
        bottomStackView.spacing = 16.0
        bottomStackView.addOption(button: self.loginButton, text: StringsProvider.string(forKey: .introLogin))
        bottomStackView.addOption(button: self.backButton, text: StringsProvider.string(forKey: .introBack))
        
        let bottomView = UIView()
        bottomView.addGradientView(.init(type: .defaultBackground))
        bottomView.addSubview(bottomStackView)
        bottomStackView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 16.0,
                                                                        left: Constants.Style.DefaultHorizontalMargins,
                                                                        bottom: 16.0,
                                                                        right: Constants.Style.DefaultHorizontalMargins))
        self.view.addSubview(bottomView)
        bottomView.autoPinEdgesToSuperviewSafeArea(with: UIEdgeInsets.zero, excludingEdge: .top)
        
        scrollView.autoPinEdge(.bottom, to: .top, of: bottomView)
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.navigationController?.navigationBar.apply(style: NavigationBarStyles.darkStyle)
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(image: ImagePalette.image(withName: .backButton),
                                                                style: .plain, target: self,
                                                                action: #selector(self.backButtonPressed))
    }
    
    // MARK: Actions
    
    @objc private func showLogin() {
        self.navigator.showLogin(presenter: self)
    }
    
    @objc private func backButtonPressed() {
        self.navigationController?.popViewController(animated: true)
    }
}

fileprivate extension UIStackView {
    func addOption(button: UIButton, text: String) {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 16.0
        stackView.addArrangedSubview(button)
        button.setContentHuggingPriority(UILayoutPriority(1000), for: .horizontal)
        button.setContentCompressionResistancePriority(UILayoutPriority(1000), for: .horizontal)
        stackView.addLabel(text: text,
                           font: FontPalette.font(withSize: 15.0),
                           textColor: ColorPalette.color(withType: .secondaryText),
                           textAlignment: .left)
        self.addArrangedSubview(stackView)
    }
}
