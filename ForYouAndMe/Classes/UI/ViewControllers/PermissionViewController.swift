//
//  PermissionViewController.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 14/09/2020.
//

import PureLayout
import RxSwift

/// The SensorKit permission row's presentation state (FUAM-3945 round 9, D7). Label and action
/// answer two DIFFERENT questions and the round-8 fix conflated them (review F3):
/// - the LABEL says whether anything was ever granted ("Manage" vs "Setup");
/// - the ACTION says whether a request round could still change something — as long as one
///   effective, non-refused sensor is `.notDetermined`, tapping must re-run the request flow
///   (a participant who cancelled prompt 2 of 8 gets prompts 2..8 again); only when nothing is
///   promptable is the Settings alert the right answer.
struct SensorKitPermissionRowState: Equatable {

    enum Action: Equatable {
        case requestFlow
        case settingsAlert
    }

    let showsManageLabel: Bool
    let action: Action

    static func resolve(anyAuthorized: Bool, hasRequestableUndetermined: Bool) -> SensorKitPermissionRowState {
        return SensorKitPermissionRowState(showsManageLabel: anyAuthorized,
                                           action: hasRequestableUndetermined ? .requestFlow : .settingsAlert)
    }
}

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
               HostAppConfig.healthKitIgnoresOptInConsent
                   || (self.repository.currentUser?.getHasAgreedTo(systemPermission: .health) ?? false) {
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

        // FUAM-3844: with the host-app flag set there is no opt-in card carrying `health`,
        // so the row must show without a recorded agreement or HealthKit could never be granted.
        if self.healthService.serviceAvailable,
           HostAppConfig.healthKitIgnoresOptInConsent
               || (self.repository.currentUser?.getHasAgreedTo(systemPermission: .health) ?? false) {
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
        // Show the SensorKit row whenever both hold (FUAM-3432):
        //  (a) the study's backend declares SensorKit a supported integration, and
        //  (b) the app is configured with >=1 SensorKit sensor — i.e. sensorKitService is
        //      non-nil (SensorKitManager is only built with a non-empty readSensors set), which
        //      is the runtime proxy for "the app has >=1 SensorKit entitlement". serviceAvailable
        //      is `true` whenever that manager exists.
        // This is independent of onboarding/identity: a user who skipped SensorKit in onboarding
        // (no identity) still sees the row, and the tap handler starts the permission/identity flow.
        if self.sensorKitService?.serviceAvailable == true,
           IntegrationProvider.isSensorKitSupported() {

            // "Manage" as soon as ANY configured sensor is .authorized; "Setup" only while the
            // participant has granted nothing yet (FUAM-3945 round 8: "no sensor is still
            // .notDetermined" never came true on a host whose entitlement does not cover a
            // requested sensor, wedging the row on "Setup" after a full grant). The label and
            // the tap ACTION are two different questions — see `SensorKitPermissionRowState`.
            let skRowState = self.sensorKitRowState()
            let skTrailingKey: StringKey = skRowState.showsManageLabel
                ? .permissionSensorKitManageLabel
                : .permissionSensorKitSetupLabel

            let skTitle = StringsProvider.string(forKey: .permissionSensorKitDescription)
            // FUAM-3945 round 9 (cell bug S3): the row gets its own icon when the asset exists —
            // host bundle first, framework second — and keeps the legacy heart otherwise, so no
            // host is left with a missing image.
            let skIconName: ImageName = ImagePalette.image(withName: .sensorKitIcon) != nil ? .sensorKitIcon : .healthIcon
            let skItem = PermissionItemView(
                withTitle: skTitle,
                isAuthorized: nil,
                iconName: skIconName,
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
    
#if SENSORKIT
    /// Label + action for the SensorKit row, from the two predicates D7 keeps separate.
    private func sensorKitRowState() -> SensorKitPermissionRowState {
        guard let manager = self.sensorKitService as? SensorKitManager else {
            return SensorKitPermissionRowState.resolve(anyAuthorized: false, hasRequestableUndetermined: false)
        }
        return SensorKitPermissionRowState.resolve(anyAuthorized: manager.hasAnyAuthorized(),
                                                   hasRequestableUndetermined: manager.hasRequestableUndeterminedSensors())
    }
#endif

    private func handleSensorKitPermission() {
#if SENSORKIT
        // We need the concrete manager to access utility methods
        guard let manager = self.sensorKitService as? SensorKitManager else { return }

        // FUAM-3945 round 9 (D7, review F3): the ACTION gate is "could a request round still
        // change something", NOT the label's "was anything granted". Round 8 gated the action on
        // `hasAnyAuthorized`, which removed the only path that could re-prompt a
        // partially-granted set: a participant who granted sensor 1 and cancelled prompt 2 was
        // permanently locked out of prompts 2..8 (iOS Settings cannot grant a never-prompted
        // sensor). Refused sensors are excluded from the predicate, so an unentitled leftover
        // cannot re-open the request flow forever either.
        if self.sensorKitRowState().action == .requestFlow {
            // Run the system request flow for the requestable .notDetermined sensors, then
            // refresh — the row flips to "Manage" as soon as anything is granted. We do NOT
            // surface the settings popup here: that popup is the settings-only action, shown
            // when no prompt can change anything any more (FUAM-3432).
            manager.requestPermissionsDetectingCollectionDisabled()
                .subscribe(onSuccess: { [weak self] outcome in
                    guard let self = self else { return }
                    switch outcome {
                    case .collectionDisabledSystemWide:
                        // EVERY asked sensor auto-declined instantly: the system-wide SensorKit
                        // master switch is OFF, iOS refuses to prompt, so guide the user to
                        // re-enable it (FUAM-3432). Do NOT nudge the recording/sync pipeline here.
                        self.navigator.showSensorKitCollectionDisabledAlert(presenter: self)
                    case .completed:
                        // Start readers and sync now that we (may) have permissions
                        manager.ensureRecordingStarted()
                        manager.triggerSync(reason: "permissions_view")
                        self.refreshStatus()
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
#endif
    }
}
