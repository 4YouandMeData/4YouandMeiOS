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
    
    public static let bottomViewHeight: CGFloat = 180
    
    private let navigator: AppNavigator
    
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
        
        stackView.addHeaderImage(image: ImagePalette.image(withName: .fyamLogoGeneric))
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
        bottomStackView.distribution = .fillEqually
        bottomStackView.addOption(image: ImagePalette.image(withName: .nextButtonLight),
                                  text: StringsProvider.string(forKey: .introLogin),
                                  target: self,
                                  selector: #selector(self.showLogin))
        bottomStackView.addOption(image: ImagePalette.image(withName: .nextButtonLight),
                                  text: StringsProvider.string(forKey: .introSetupLater),
                                  target: self,
                                  selector: #selector(self.setupLaterPressed))
        
        let bottomView = UIView()
        bottomView.autoSetDimension(.height, toSize: Self.bottomViewHeight)
        bottomView.addShadowLinear(goingDown: false)
        bottomView.addGradientView(.init(type: .defaultBackground))
        bottomView.addSubview(bottomStackView)
        bottomStackView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 20.0,
                                                                        left: Constants.Style.DefaultHorizontalMargins,
                                                                        bottom: 20.0,
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
        self.navigator.goBackToWelcome(presenter: self)
    }
    
    @objc private func setupLaterPressed() {
        self.navigator.showSetupLater(presenter: self)
    }
}

fileprivate extension UIStackView {
    func addOption(image: UIImage?, text: String, target: Any, selector: Selector) {
        let containerView = UIView()
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 16.0
        
        let imageView = UIImageView(image: image)
        stackView.addArrangedSubview(imageView)
        imageView.setContentHuggingPriority(UILayoutPriority(1000), for: .horizontal)
        imageView.setContentCompressionResistancePriority(UILayoutPriority(1000), for: .horizontal)
        stackView.addLabel(text: text,
                           font: FontPalette.font(withSize: 15.0),
                           textColor: ColorPalette.color(withType: .secondaryText),
                           textAlignment: .left,
                           numberOfLines: 2,
                           lineSpacing: 7.0)
        containerView.addSubview(stackView)
        stackView.autoPinEdge(toSuperviewEdge: .leading)
        stackView.autoPinEdge(toSuperviewEdge: .trailing)
        stackView.autoPinEdge(toSuperviewEdge: .top, withInset: 0.0, relation: .greaterThanOrEqual)
        stackView.autoPinEdge(toSuperviewEdge: .bottom, withInset: 0.0, relation: .greaterThanOrEqual)
        stackView.autoAlignAxis(toSuperviewAxis: .horizontal)
        
        let button = UIButton()
        button.backgroundColor = UIColor.clear
        button.addTarget(target, action: selector, for: .touchUpInside)
        containerView.addSubview(button)
        button.autoPinEdge(.top, to: .top, of: stackView)
        button.autoPinEdge(.leading, to: .leading, of: stackView)
        button.autoPinEdge(.trailing, to: .trailing, of: stackView)
        button.autoPinEdge(.bottom, to: .bottom, of: stackView)
        
        self.addArrangedSubview(containerView)
    }
}
