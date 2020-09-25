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
    private let analytics: AnalyticsService
    
    init() {
        self.navigator = Services.shared.navigator
        self.analytics = Services.shared.analytics
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.addGradientView(GradientView(type: .primaryBackground))
        
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
        stackView.addBlankSpace(space: 40.0)
        stackView.addLabel(withText: StringsProvider.string(forKey: .introTitle),
                           fontStyle: .title,
                           colorType: .secondaryText,
                           textAlignment: .left)
        stackView.addBlankSpace(space: 30.0)
        stackView.addLabel(withText: StringsProvider.string(forKey: .introBody),
                           fontStyle: .paragraph,
                           colorType: .secondaryText,
                           textAlignment: .left)
        let bottomStackView = UIStackView()
        bottomStackView.axis = .vertical
        bottomStackView.distribution = .fillEqually
        bottomStackView.addOption(image: ImagePalette.image(withName: .nextButtonSecondary),
                                  text: StringsProvider.string(forKey: .introLogin),
                                  target: self,
                                  selector: #selector(self.showLogin))
        bottomStackView.addOption(image: ImagePalette.image(withName: .nextButtonSecondary),
                                  text: StringsProvider.string(forKey: .introSetupLater),
                                  target: self,
                                  selector: #selector(self.setupLaterPressed))
        
        let bottomView = UIView()
        bottomView.autoSetDimension(.height, toSize: Self.bottomViewHeight)
        bottomView.addShadowLinear(goingDown: false)
        bottomView.addGradientView(.init(type: .primaryBackground))
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
        self.analytics.track(event: .recordScreen(screenName: AnalyticsScreens.requestSetUp.rawValue,
                                                  screenClass: String(describing: type(of: self))))
        self.navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.primary(hidden: false).style)
        self.addCustomBackButton()
    }
    
    // MARK: Actions
    
    @objc private func showLogin() {
        self.navigator.showLogin(presenter: self)
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
        imageView.autoSetDimensions(to: CGSize(width: 50.0, height: 50.0))
        stackView.addLabel(withText: text,
                           fontStyle: .header3,
                           colorType: .secondaryText,
                           textAlignment: .left,
                           numberOfLines: 2)
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
