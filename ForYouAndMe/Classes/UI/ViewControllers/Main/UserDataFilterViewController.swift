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
    
    private let userDataAggregationFilterData: [UserDataAggregationFilter]
    
    private lazy var closeButton: UIButton = {
        let button = UIButton()
        button.setImage(ImagePalette.templateImage(withName: .closeButton), for: .normal)
        button.tintColor = ColorPalette.color(withType: .secondaryText)
        button.autoSetDimension(.width, toSize: 32)
        button.imageView?.contentMode = .scaleAspectFit
        button.addTarget(self, action: #selector(self.closeButtonPressed), for: .touchUpInside)
        return button
    }()
    
    private lazy var headerView: UIView = {
        let containerView = UIView()
        containerView.addGradientView(GradientView(type: .primaryBackground))
        
        let stackView = UIStackView.create(withAxis: .vertical, spacing: 20.0)
        
        // Close button
        let closeButtonContainerView = UIView()
        closeButtonContainerView.addSubview(self.closeButton)
        self.closeButton.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .trailing)
        stackView.addArrangedSubview(closeButtonContainerView)

        stackView.addLabel(withText: StringsProvider.string(forKey: .userDataFilterTitle),
                           fontStyle: .title,
                           colorType: .secondaryText)
        
        containerView.addSubview(stackView)
        stackView.autoPinEdgesToSuperviewSafeArea(with: UIEdgeInsets(top: 25.0,
                                                                     left: Constants.Style.DefaultHorizontalMargins,
                                                                     bottom: 26.0,
                                                                     right: Constants.Style.DefaultHorizontalMargins))
        return containerView
    }()
    
    private lazy var scrollStackView: ScrollStackView = {
        let scrollStackView = ScrollStackView(axis: .vertical, horizontalInset: 0.0)
        return scrollStackView
    }()
    
    private lazy var confirmButtonView: GenericButtonView = {
        let view = GenericButtonView(withTextStyleCategory: .secondaryBackground())
        view.setButtonText(StringsProvider.string(forKey: .userDataFilterSaveButton))
        view.addTarget(target: self, action: #selector(self.confirmButtonPressed))
        return view
    }()
    
    private var storage: CacheService
    private var excludedUserDataAggregationIds: [String]
    
    init(withUserDataAggregationFilterData userDataAggregationFilterData: [UserDataAggregationFilter]) {
        self.navigator = Services.shared.navigator
        self.repository = Services.shared.repository
        self.storage = Services.shared.storageServices
        self.analytics = Services.shared.analytics
        self.userDataAggregationFilterData = userDataAggregationFilterData
        self.excludedUserDataAggregationIds = self.storage.excludedUserDataAggregationIds ?? []
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
        
        // Main Stack View
        let stackView = UIStackView.create(withAxis: .vertical)
        self.view.addSubview(stackView)
        stackView.autoPinEdgesToSuperviewEdges()
        
        stackView.addArrangedSubview(self.headerView)
        stackView.addArrangedSubview(self.scrollStackView)
        stackView.addArrangedSubview(self.confirmButtonView)
        
        // TODO: Show items,
        // TODO: Handle selection
        // TODO: Update UI accordingly
        // TODO: Update the excludedUserDataAggregationIds array accordingly
        // TODO: Add clear/select all button
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.analytics.track(event: .recordScreen(screenName: AnalyticsScreens.yourDataFilter.rawValue,
                                                  screenClass: String(describing: type(of: self))))
        self.navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.primary(hidden: true).style)
    }
    
    // MARK: - Actions
    
    @objc private func confirmButtonPressed() {
        self.storage.excludedUserDataAggregationIds = self.excludedUserDataAggregationIds
        self.customCloseButtonPressed()
    }
    
    @objc private func closeButtonPressed() {
        self.customCloseButtonPressed()
    }
}
