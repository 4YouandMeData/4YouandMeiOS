//
//  DevicesIntegrationViewController.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 11/09/2020.
//

import UIKit
import RxSwift

public class DevicesIntegrationViewController: UIViewController {
    
    private static let IntegrationItemHeight: CGFloat = 72.0
    
    private var titleString: String
    private let navigator: AppNavigator
    private let analytics: AnalyticsService
    private let repository: Repository
    
    private let disposeBag = DisposeBag()
    
    private lazy var scrollStackView: ScrollStackView = {
        let scrollStackView = ScrollStackView(axis: .vertical, horizontalInset: 0.0)
        return scrollStackView
    }()
    
    init(withTitle title: String) {
        self.titleString = title
        self.navigator = Services.shared.navigator
        self.analytics = Services.shared.analytics
        self.repository = Services.shared.repository
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
        
        self.refreshUI()
    }
    
    private func refreshUI() {
        self.scrollStackView.stackView.arrangedSubviews.forEach({ $0.removeFromSuperview() })
        
        guard let currentUser = Services.shared.repository.currentUser,
              let navigationController = self.navigationController else {
            return
        }
        
        IntegrationProvider.oAuthIntegrations().forEach { integration in
            var connected = currentUser.identities.contains(integration.rawValue)

            if integration == .terra {
                connected = false
            }
            
            let item = DeviceItemView(withTitle: integration.title,
                imageName: integration.icon,
                connected: connected,
                gestureCallback: { [weak self] in
                let loginUrl = (connected) ? integration.apiOAuthDeauthorizeUrl : integration.apiOAuthUrl
                self?.navigator.showIntegrationLogin(loginUrl: loginUrl,
                                                      navigationController: navigationController)
            })
            self.scrollStackView.stackView.addArrangedSubview(item)
            item.autoSetDimension(.height, toSize: Self.IntegrationItemHeight)
        }
        
        self.scrollStackView.stackView.addBlankSpace(space: 40.0)
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.analytics.track(event: .recordScreen(screenName: AnalyticsScreens.openAppsAndDevices.rawValue,
                                                  screenClass: String(describing: type(of: self))))
        self.navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.primary(hidden: true).style)
        
        self.repository.refreshUser()
            .toVoid()
            .catchAndReturn(())
            .addProgress()
            .subscribe(onSuccess: { [weak self] in
                guard let self = self else { return }
                self.refreshUI()
            })
            .disposed(by: self.disposeBag)
    }
    
    // MARK: Actions
    
    @objc private func backButtonPressed() {
        self.navigationController?.popViewController(animated: true)
    }
}

fileprivate extension Integration {
    var icon: ImageName {
        switch self {
        case .oura: return .ouraIcon
        case .fitbit: return .fitbitIcon
        case .garmin: return .garminIcon
        case .instagram: return .instagramIcon
        case .rescueTime: return .rescueTimeIcon
        case .twitter: return .twitterIcon
        case .dexcom: return .garminIcon
        case .terra: return .terraIcon
        case .empatica: return .terraIcon
        }
    }
    var title: String {
        switch self {
        case .oura: return StringsProvider.string(forKey: .ouraOauthTitle)
        case .fitbit: return StringsProvider.string(forKey: .fitbitOauthTitle)
        case .garmin: return StringsProvider.string(forKey: .garminOauthTitle)
        case .instagram: return StringsProvider.string(forKey: .instagramOauthTitle)
        case .rescueTime: return StringsProvider.string(forKey: .rescueTimeOauthTitle)
        case .twitter: return StringsProvider.string(forKey: .twitterOauthTitle)
        case .dexcom: return StringsProvider.string(forKey: .dexComOauthTitle)
        case .terra: return StringsProvider.string(forKey: .terraTitle)
        case .empatica: return StringsProvider.string(forKey: .empaticaTitle)
        }
    }
}
