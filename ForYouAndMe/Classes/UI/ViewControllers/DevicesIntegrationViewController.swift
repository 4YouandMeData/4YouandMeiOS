//
//  DevicesIntegrationViewController.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 11/09/2020.
//

import PureLayout

public class DevicesIntegrationViewController: UIViewController {
    
    private var titleString: String
    private let navigator: AppNavigator
    private let analytics: AnalyticsService
    
    private lazy var scrollStackView: ScrollStackView = {
        let scrollStackView = ScrollStackView(axis: .vertical, horizontalInset: 0.0)
        return scrollStackView
    }()
    
    init(withTitle title: String) {
        self.titleString = title
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
        
        // Header View
        let headerView = InfoDetailHeaderView(withTitle: self.titleString )
        self.view.addSubview(headerView)
        headerView.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .bottom)
        headerView.backButton.addTarget(self, action: #selector(self.backButtonPressed), for: .touchUpInside)
        // ScrollStackView
        self.scrollStackView = ScrollStackView(axis: .vertical, horizontalInset: Constants.Style.DefaultHorizontalMargins)
        self.view.addSubview(scrollStackView)
        self.scrollStackView.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .top)
        self.scrollStackView.autoPinEdge(.top, to: .bottom, of: headerView, withOffset: 30)
        self.scrollStackView.stackView.spacing = 30
        
        let garminItem = DeviceItemView(withTitle: "Garmin"/*StringsProvider.string(forKey: .studyInfoRewardsItem)*/,
            imageName: .fitbitIcon,
            connected: false,
            gestureCallback: { [weak self] in
                self?.navigator.showWearableLogin(loginUrl: URL(string: "https://admin-4youandme-staging.balzo.eu/users/integration_oauth/garmin")!,
                                                  navigationController: self?.navigationController ?? UINavigationController())
        })
        self.scrollStackView.stackView.addArrangedSubview(garminItem)
        garminItem.autoSetDimension(.height, toSize: 72)
        
        let ouraItem = DeviceItemView(withTitle: "Oura"/*StringsProvider.string(forKey: .studyInfoRewardsItem)*/,
            imageName: .ouraIcon,
            connected: false,
            gestureCallback: { [weak self] in
                self?.navigator.showWearableLogin(loginUrl: URL(string: "https://admin-4youandme-staging.balzo.eu/users/integration_oauth/oura")!,
                                                  navigationController: self?.navigationController ?? UINavigationController())
        })
        self.scrollStackView.stackView.addArrangedSubview(ouraItem)
        ouraItem.autoSetDimension(.height, toSize: 72)
        
        self.scrollStackView.stackView.addBlankSpace(space: 40.0)
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.analytics.track(event: .recordScreen(screenName: AnalyticsScreens.openAppsAndDevices.rawValue,
                                                  screenClass: String(describing: type(of: self))))
        self.navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.primary(hidden: true).style)
    }
    
    // MARK: Actions
    
    @objc private func backButtonPressed() {
        self.navigationController?.popViewController(animated: true)
    }
}
