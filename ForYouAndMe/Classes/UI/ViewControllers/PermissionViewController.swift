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
    private let repository: Repository
    private let analytics: AnalyticsService
    private let healthService: HealthService
    private let deviceService: DeviceService
#if SENSORKIT
    private let sensorKitService: SensorKitService?
#endif
    private let disposeBag: DisposeBag = DisposeBag()
    
    private lazy var scrollStackView: ScrollStackView = {
        let scrollStackView = ScrollStackView(axis: .vertical, horizontalInset: 0.0)
        return scrollStackView
    }()
    
    init(withTitle title: String) {
        self.titleString = title
        self.navigator = Services.shared.navigator
        self.repository = Services.shared.repository
        self.analytics = Services.shared.analytics
        self.healthService = Services.shared.healthService
        self.deviceService = Services.shared.deviceService
#if SENSORKIT
        self.sensorKitService = Services.shared.sensorKitService
#endif
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = ColorPalette.color(withType: .secondaryBackgroungColor)
        
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
        // Query async row-state inputs up front (HealthKit shouldRequest; the SK
        // hasAnyAuthorized check is synchronous and is invoked inline below).
        // Once both are resolved we rebuild the stack on the main thread.
        let healthSetupSingle: Single<Bool> = {
            if self.healthService.serviceAvailable,
               self.repository.currentUser?.getHasAgreedTo(systemPermission: .health) ?? false {
                // True → no read type has ever been requested → "Setup".
                return self.healthService.isStillShouldRequest().catchAndReturn(false)
            }
            return .just(false)
        }()

        healthSetupSingle
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] healthShouldSetup in
                guard let self = self else { return }
                self.rebuildPermissionRows(healthShouldSetup: healthShouldSetup)
            }, onFailure: { [weak self] _ in
                // Best-effort: fall back to the "Manage" label if the check fails.
                self?.rebuildPermissionRows(healthShouldSetup: false)
            })
            .disposed(by: self.disposeBag)
    }

    private func rebuildPermissionRows(healthShouldSetup: Bool) {

        self.scrollStackView.stackView.arrangedSubviews.forEach({ $0.removeFromSuperview() })

        if self.deviceService.locationServicesAvailable, self.repository.currentUser?.getHasAgreedTo(systemPermission: .location) ?? false {
            let permissionLocation: Permission = Constants.Misc.DefaultLocationPermission
            let locationTitle = StringsProvider.string(forKey: .permissionLocationDescription)
            let locationItem = PermissionItemView(withTitle: locationTitle,
                                                  isAuthorized: permissionLocation.isAuthorized,
                                                  iconName: .locationIcon,
                                                  gestureCallback: { [weak self] in
                                                    self?.handleLocationPermission(permission: permissionLocation)
                                                  })
            self.scrollStackView.stackView.addArrangedSubview(locationItem)
        }

        let notificationPermission: Permission = .notification
        let notificationTitle = StringsProvider.string(forKey: .permissionPushNotificationDescription)
        let pushItem = PermissionItemView(withTitle: notificationTitle,
                                          isAuthorized: notificationPermission.isAuthorized,
                                          iconName: .pushNotificationIcon,
                                          gestureCallback: { [weak self] in
            guard let self = self else { return }
            self.handlePushNotificationPermission(permission: notificationPermission)
        })
        pushItem.autoSetDimension(.height, toSize: 72, relation: .greaterThanOrEqual)

        self.scrollStackView.stackView.addArrangedSubview(pushItem)

        if self.healthService.serviceAvailable, self.repository.currentUser?.getHasAgreedTo(systemPermission: .health) ?? false {
            let healthItemTitle = StringsProvider.string(forKey: .permissionHealthDescription)
            // "Setup" iff getRequestStatusForAuthorization == .shouldRequest, else "Manage".
            let healthTrailingKey: StringKey = healthShouldSetup
                ? .permissionHealthSetupLabel
                : .permissionHealthManageLabel
            let healthItem = PermissionItemView(withTitle: healthItemTitle,
                                                isAuthorized: nil,
                                                iconName: .healthIcon,
                                                trailingActionText: StringsProvider.string(forKey: healthTrailingKey),
                                                gestureCallback: { [weak self] in
                                                    self?.handleHealthPermission()
                                                })
            healthItem.autoSetDimension(.height, toSize: 72, relation: .greaterThanOrEqual)
            self.scrollStackView.stackView.addArrangedSubview(healthItem)
        }

        // --- SensorKit ---
#if SENSORKIT
        // Show the SensorKit row when the service is available AND either the user already
        // has a SensorKit identity (agreed during onboarding) OR the study's backend declares
        // SensorKit as a supported integration. The latter covers users who skipped SensorKit in
        // onboarding and therefore have no identity yet — the tap handler starts the permission /
        // identity flow in that case (FUAM-3432).
        let sensorKitHasIdentity = self.repository.currentUser?.getHasAgreedTo(systemPermission: .sensorKit) ?? false
        if self.sensorKitService?.serviceAvailable == true,
           sensorKitHasIdentity || IntegrationProvider.isSensorKitSupported() {

            // "Setup" iff no sensor is .authorized (all are .notDetermined and/or
            // .denied); "Manage" otherwise. The tap handler in
            // handleSensorKitPermission already does the right thing in both cases.
            let skHasAnyAuthorized = (self.sensorKitService as? SensorKitManager)?.hasAnyAuthorized() ?? false
            let skTrailingKey: StringKey = skHasAnyAuthorized
                ? .permissionSensorKitManageLabel
                : .permissionSensorKitSetupLabel

            let skTitle = StringsProvider.string(forKey: .permissionSensorKitDescription)
            let skItem = PermissionItemView(
                withTitle: skTitle,
                isAuthorized: nil,
                iconName: .healthIcon,
                trailingActionText: StringsProvider.string(forKey: skTrailingKey),
                gestureCallback: { [weak self] in
                    self?.handleSensorKitPermission()
                }
            )
            skItem.autoSetDimension(.height, toSize: 72, relation: .greaterThanOrEqual)
            self.scrollStackView.stackView.addArrangedSubview(skItem)
        }
#endif

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
        }, onFailure: { error in
            self.navigator.handleError(error: error, presenter: self)
        }).disposed(by: self.disposeBag)
    }
    
    private func handlePushNotificationPermission(permission: Permission) {
        permission.request().subscribe(onSuccess: { [weak self] _ in
            guard let self = self else { return }
            if permission.isDenied, permission.isNotDetermined == false {
                self.navigator.showPermissionDeniedAlert(presenter: self)
            } else {
                self.navigator.openSettings()
            }
            let permissionStatus = permission.isAuthorized ?
                AnalyticsParameter.allow.rawValue :
                AnalyticsParameter.revoke.rawValue
            self.analytics.track(event: .notificationPermissionChanged(permissionStatus))
        }, onFailure: { [weak self] error in
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
                        // After a successful requestAuthorization the status should be
                        // .unnecessary. If it is still .shouldRequest, the system silently
                        // refused to display the prompt — same family of bug as the SK
                        // SRErrorPromptDeclined path. Surface the settings alert so the row
                        // is never a silent no-op (FUAM-3370). The "previously denied read
                        // types alongside new not-determined ones" case remains undetectable
                        // on Apple's side (no per-type read-authorization API by design).
                        self.healthService.isStillShouldRequest()
                            .subscribe(onSuccess: { [weak self] stillShouldRequest in
                                guard let self = self else { return }
                                if stillShouldRequest {
                                    self.navigator.showHealthPermissionSettingsAlert(presenter: self)
                                }
                            }, onFailure: { _ in
                                // Silently ignore: the request itself succeeded, this is best-effort.
                            }).disposed(by: self.disposeBag)
                    }, onFailure: { [weak self] error in
                        guard let self = self else { return }
                        self.navigator.handleError(error: error, presenter: self)
                    }).disposed(by: self.disposeBag)
                } else {
                    self.navigator.showHealthPermissionSettingsAlert(presenter: self)
                }
            }, onFailure: { [weak self] error in
                guard let self = self else { return }
                self.navigator.handleError(error: error, presenter: self)
            }).disposed(by: self.disposeBag)
    }
    
    private func handleSensorKitPermission() {
#if SENSORKIT
        // We need the concrete manager to access utility methods
        guard let manager = self.sensorKitService as? SensorKitManager else { return }

        manager.getIsAuthorizationStatusUndetermined()
            .subscribe(onSuccess: { [weak self] undetermined in
                guard let self = self else { return }

                if undetermined {
                    // Ask OS only for .notDetermined sensors
                    manager.requestPermissions()
                        .subscribe(onSuccess: { [weak self] in
                            guard let self = self else { return }
                            // Start readers and sync now that we (may) have permissions
                            manager.ensureRecordingStarted()
                            manager.triggerSync(reason: "permissions_view")
                            self.refreshStatus()
                            // The system may have refused to display the prompt
                            // (SRErrorPromptDeclined, code 4) when the user has
                            // previously declined the SensorKit-wide authorization.
                            // In that case the sensors stay .notDetermined or move
                            // to .denied with no UI shown — surface the settings
                            // alert so the row is never a silent no-op (FUAM-3370).
                            // The gap-presence check stays as the *guard* (no alert
                            // when the system properly prompted and everything is
                            // authorized), but the alert content always lists the
                            // full configured-sensor set.
                            let gaps = manager.authorizationGaps()
                            let problematic = gaps.denied.union(gaps.undetermined)
                            if !problematic.isEmpty {
                                self.navigator.showSensorKitPermissionSettingsAlert(
                                    presenter: self,
                                    missingSensors: manager.configuredSensors
                                )
                            }
                        }, onFailure: { [weak self] error in
                            guard let self = self else { return }
                            self.navigator.handleError(error: error, presenter: self)
                        })
                        .disposed(by: self.disposeBag)

                } else {
                    // SensorKit cannot re-trigger the system prompt once the user has
                    // responded, and iOS exposes no per-app SensorKit deep-link, so the
                    // only thing we can offer is the app's general Settings page.
                    // Always show the alert so the row is never a silent no-op (FUAM-3370).
                    // The alert content always lists the full configured-sensor set
                    // regardless of per-sensor authorization state.
                    let gaps = manager.authorizationGaps() // (undetermined, denied)
                    self.navigator.showSensorKitPermissionSettingsAlert(
                        presenter: self,
                        missingSensors: manager.configuredSensors
                    )
                    // Keep the prior behaviour for the all-authorized case: nudge the
                    // recording pipeline and refresh the status badge in the background.
                    if gaps.denied.isEmpty {
                        manager.ensureRecordingStarted()
                        manager.triggerSync(reason: "permissions_view_already")
                        self.refreshStatus()
                    }
                }
            }, onFailure: { [weak self] error in
                guard let self = self else { return }
                self.navigator.handleError(error: error, presenter: self)
            })
            .disposed(by: self.disposeBag)
#endif
    }
}
