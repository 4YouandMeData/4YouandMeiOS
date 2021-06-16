//
//  UserDataFilterViewController.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 16/06/21.
//

import UIKit

class UserDataFilterViewController: UIViewController {
    
    private let navigator: AppNavigator
    private let repository: Repository
    private let analytics: AnalyticsService
    
    private lazy var closeButton: UIButton = {
        let button = UIButton()
        button.setImage(ImagePalette.templateImage(withName: .closeButton), for: .normal)
        button.tintColor = ColorPalette.color(withType: .secondaryText)
        button.autoSetDimension(.width, toSize: 32)
        button.imageView?.contentMode = .scaleAspectFit
        return button
    }()
    
    private lazy var headerView: UIView = {
        let containerView = UIView()
        containerView.addGradientView(GradientView(type: .primaryBackground))
        
        let stackView = UIStackView.create(withAxis: .vertical, spacing: 40.0)
        
        // Close button
        let closeButtonContainerView = UIView()
        closeButtonContainerView.addSubview(self.closeButton)
        self.closeButton.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .trailing)
        stackView.addArrangedSubview(closeButtonContainerView)

        stackView.addLabel(withText: StringsProvider.string(forKey: .userDataFilterTitle),
                           fontStyle: .title,
                           colorType: .secondaryText)
        
        containerView.addSubview(stackView)
        stackView.autoPinEdgesToSuperviewSafeArea(with: UIEdgeInsets(top: 20,
                                                                     left: Constants.Style.DefaultHorizontalMargins,
                                                                     bottom: 30.0,
                                                                     right: Constants.Style.DefaultHorizontalMargins))
        return containerView
    }()
    
    private lazy var scrollStackView: ScrollStackView = {
        let scrollStackView = ScrollStackView(axis: .vertical, horizontalInset: 0.0)
        return scrollStackView
    }()
    
    init() {
        self.navigator = Services.shared.navigator
        self.repository = Services.shared.repository
        self.analytics = Services.shared.analytics
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        print("AboutYouViewController - deinit")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = ColorPalette.color(withType: .secondary)
        
        // Header View
        self.view.addSubview(self.headerView)
        self.headerView.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .bottom)
        self.closeButton.addTarget(self, action: #selector(self.closeButtonDidPressed), for: .touchUpInside)
        
        // ScrollStackView
        self.view.addSubview(self.scrollStackView)
        self.scrollStackView.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .top)
        self.scrollStackView.autoPinEdge(.top, to: .bottom, of: headerView, withOffset: 30)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.analytics.track(event: .recordScreen(screenName: AnalyticsScreens.yourDataFilter.rawValue,
                                                  screenClass: String(describing: type(of: self))))
        self.navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.primary(hidden: true).style)
    }
    
    // MARK: - Actions
    
    @objc private func closeButtonDidPressed() {
        self.customCloseButtonPressed()
    }
}
