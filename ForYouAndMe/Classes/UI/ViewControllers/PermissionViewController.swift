//
//  PermissionViewController.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 14/09/2020.
//

import PureLayout
import RxSwift

public class PermissionViewController: UIViewController {
    
    private var titleString: String
    private let navigator: AppNavigator
    private let analytics: AnalyticsService
    private let healthService: HealthService
    private let disposeBag: DisposeBag = DisposeBag()
    
    private lazy var scrollStackView: ScrollStackView = {
        let scrollStackView = ScrollStackView(axis: .vertical, horizontalInset: 0.0)
        return scrollStackView
    }()
    
    init(withTitle title: String) {
        self.titleString = title
        self.navigator = Services.shared.navigator
        self.analytics = Services.shared.analytics
        self.healthService = Services.shared.healthService
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
        
        self.refreshStatus()
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.analytics.track(event: .recordScreen(screenName: AnalyticsScreens.openPermissions.rawValue,
                                                  screenClass: String(describing: type(of: self))))
        self.navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.primary(hidden: true).style)
    }
    
    // MARK: Actions
    @objc private func backButtonPressed() {
        self.navigationController?.popViewController(animated: true)
    }
    
    private func refreshStatus() {
        
        self.scrollStackView.stackView.arrangedSubviews.forEach({ $0.removeFromSuperview() })
        
        let permissionLocation: Permission = Constants.Misc.DefaultLocationPermission

        let locationTitle = StringsProvider.string(forKey: .permissionLocationDescription)
        let locationItem = PermissionItemView(withTitle: locationTitle,
                                              isAuthorized: permissionLocation.isAuthorized,
                                              iconName: .locationIcon,
                                              gestureCallback: { [weak self] in
                                                self?.handleLocationPermission(permission: permissionLocation)
        })
        self.scrollStackView.stackView.addArrangedSubview(locationItem)
        
        let notificationPermission: Permission = .notification
        let notificationTitle = StringsProvider.string(forKey: .permissionPushNotificationDescription)
        let pushItem = PermissionItemView(withTitle: notificationTitle,
                                          isAuthorized: notificationPermission.isAuthorized,
                                          iconName: .pushNotificationIcon,
                                          gestureCallback: { [weak self] in
                                            self?.handlePushNotificationPermission(permission: notificationPermission)
        })
        pushItem.autoSetDimension(.height, toSize: 72, relation: .greaterThanOrEqual)
        
        self.scrollStackView.stackView.addArrangedSubview(pushItem)
        
        if self.healthService.serviceAvailable {
            let healthItemTitle = StringsProvider.string(forKey: .permissionHealthDescription)
            let healthItem = PermissionItemView(withTitle: healthItemTitle,
                                                isAuthorized: nil,
                                                iconName: .healthIcon,
                                                gestureCallback: { [weak self] in
                                                    self?.handleHealthPermission()
                                                })
            healthItem.autoSetDimension(.height, toSize: 72, relation: .greaterThanOrEqual)
            self.scrollStackView.stackView.addArrangedSubview(healthItem)
        }
            
        self.scrollStackView.stackView.addBlankSpace(space: 40.0)
    }
    
    private func handleLocationPermission(permission: Permission) {
        permission.request().subscribe(onSuccess: { _ in
            if permission.isDenied, permission.isNotDetermined == false {
                self.navigator.showPermissionDeniedAlert(presenter: self)
            } else {
                self.refreshStatus()
            }
            let permissionStatus = permission.isAuthorized ?
                AnalyticsParameter.allow.rawValue :
                AnalyticsParameter.revoke.rawValue
            self.analytics.track(event: .locationPermissionChanged(permissionStatus))
        }, onError: { error in
            self.navigator.handleError(error: error, presenter: self)
        }).disposed(by: self.disposeBag)
    }
    
    private func handlePushNotificationPermission(permission: Permission) {
        permission.request().subscribe(onSuccess: { [weak self] _ in
            guard let self = self else { return }
            if permission.isDenied, permission.isNotDetermined == false {
                self.navigator.showPermissionDeniedAlert(presenter: self)
            } else {
                self.refreshStatus()
            }
            let permissionStatus = permission.isAuthorized ?
                AnalyticsParameter.allow.rawValue :
                AnalyticsParameter.revoke.rawValue
            self.analytics.track(event: .notificationPermissionChanged(permissionStatus))
        }, onError: { [weak self] error in
            guard let self = self else { return }
            self.navigator.handleError(error: error, presenter: self)
        }).disposed(by: self.disposeBag)
    }
    
    private func handleHealthPermission() {
        self.healthService
            .getIsAuthorizationStatusUndetermined()
            .subscribe(onSuccess: { [weak self] undetermined in
                guard let self = self else { return }
                if undetermined {
                    self.healthService.requestPermissions().subscribe(onSuccess: { [weak self] _ in
                        guard let self = self else { return }
                        self.refreshStatus()
                        // TODO: Send analytics?
//                        let permissionStatus = self.healthService.permissionsGranted ?
//                            AnalyticsParameter.allow.rawValue :
//                            AnalyticsParameter.revoke.rawValue
//                        self.analytics.track(event: .healthPermissionChanged(permissionStatus))
                    }, onError: { [weak self] error in
                        guard let self = self else { return }
                        self.navigator.handleError(error: error, presenter: self)
                    }).disposed(by: self.disposeBag)
                } else {
                    self.navigator.showHealthPermissionSettingsAlert(presenter: self)
                }
            }, onError: { [weak self] error in
                guard let self = self else { return }
                self.navigator.handleError(error: error, presenter: self)
            }).disposed(by: self.disposeBag)
    }
}
