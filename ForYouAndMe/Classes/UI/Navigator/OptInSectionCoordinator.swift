//
//  OptInSectionCoordinator.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 23/06/2020.
//

import Foundation
import RxSwift

class OptInSectionCoordinator {
    
    // MARK: - Coordinator
    var hidesBottomBarWhenPushed: Bool = false
    
    // MARK: - PagedSectionCoordinator
    var addAbortOnboardingButton: Bool = true
    
    public unowned var navigationController: UINavigationController
    
    private let repository: Repository
    private let navigator: AppNavigator
    
    private let sectionData: OptInSection
    private let completionCallback: NavigationControllerCallback
    
    private let disposeBag = DisposeBag()
    
    private let healthService: HealthService
    private let deviceService: DeviceService
    #if HEALTHKIT
    private let sensorKitService: SensorKitService?
    #endif
    
    var answers: [Question: PossibleAnswer] = [:]
    
    init(withSectionData sectionData: OptInSection,
         navigationController: UINavigationController,
         completionCallback: @escaping NavigationControllerCallback) {
        self.repository = Services.shared.repository
        self.navigator = Services.shared.navigator
        self.healthService = Services.shared.healthService
        self.deviceService = Services.shared.deviceService
#if HEALTHKIT
        self.sensorKitService = Services.shared.sensorKitService
#endif
        
        self.sectionData = sectionData
        self.navigationController = navigationController
        self.completionCallback = completionCallback
    }
    
    // MARK: - Private Methods
    
    private func showSuccess() {
        if let successPage = self.sectionData.successPage {
            self.showResultPage(successPage)
        } else {
            self.completionCallback(self.navigationController)
        }
    }
    
    private func showOptInPermission(_ optInPermission: OptInPermission) {
        let viewController = OptInPermissionViewController(withOptInPermission: optInPermission, coordinator: self)
        self.navigationController.pushViewController(viewController,
                                                     hidesBottomBarWhenPushed: self.hidesBottomBarWhenPushed,
                                                     animated: true)
    }
}

extension OptInSectionCoordinator: PagedSectionCoordinator {
    
    var pages: [Page] { self.sectionData.pages }
    
    func getStartingPage() -> UIViewController {
        let infoPageData = InfoPageData(page: self.sectionData.welcomePage,
                                        addAbortOnboardingButton: false,
                                        addCloseButton: false,
                                        allowBackwardNavigation: false,
                                        bodyTextAlignment: .center,
                                        bottomViewStyle: .singleButton,
                                        customImageHeight: nil,
                                        defaultButtonFirstLabel: nil,
                                        defaultButtonSecondLabel: nil)
        return InfoPageViewController(withPageData: infoPageData, coordinator: self)
    }
    
    func performCustomPrimaryButtonNavigation(page: Page) -> Bool {
        if self.sectionData.successPage?.id == page.id {
            self.completionCallback(self.navigationController)
            return true
        }
        return false
    }
    
    func onUnhandledPrimaryButtonNavigation(page: Page) {
        if let firstOptInPermission = self.sectionData.optInPermissions.first {
            self.showOptInPermission(firstOptInPermission)
        } else {
            self.completionCallback(self.navigationController)
        }
    }
}

extension OptInSectionCoordinator: OptInPermissionCoordinator {
    func onOptInPermissionSet(optInPermission: OptInPermission, granted: Bool) {
        
        guard granted || false == optInPermission.isMandatory else {
            let message = optInPermission.mandatoryText ?? StringsProvider.string(forKey: .onboardingOptInMandatoryDefault)
            self.navigationController.showAlert(withTitle: StringsProvider.string(forKey: .onboardingOptInMandatoryTitle),
                                                message: message,
                                                dismissButtonText: StringsProvider.string(forKey: .onboardingOptInMandatoryClose))
            return
        }
        
        // FUAM-3014: system permission prompts (HealthKit, SensorKit, …) dismiss asynchronously.
        // Their completion handlers can fire while the presenting view controller is still
        // animating out, so presenting the next prompt immediately lands on a view that is
        // no longer in the window hierarchy — UIKit silently drops the presentation and the
        // chain hangs. A small delay between steps gives the previous prompt's dismissal
        // animation time to finish before the next step runs.
        let interStepDelay: Single<()> = Single.just(())
            .delay(.milliseconds(500), scheduler: MainScheduler.instance)

        let systemPermissionRequests: Single<()> = optInPermission.systemPermissions
            .reduce(Single.just(())) { (result, systemPermission) in
            switch systemPermission {
            case .health:
                return result.flatMap {
                    return granted ? self.healthService.requestPermissions().catchAndReturn(()) : Single.just(())
                }.flatMap { interStepDelay }
            case .location:
                return result.flatMap {
                    guard self.deviceService.locationServicesAvailable else {
                        // location services not enabled for this study: do nothing (no native permission popup should be shown)
                        return Single.just(())
                    }
                    let permission: Permission = Constants.Misc.DefaultLocationPermission
                    return granted ? permission.request().catchAndReturn(()) : Single.just(())
                }.flatMap { interStepDelay }
            case .notification:
                return result.flatMap {
                    let permission: Permission = .notification
                    return granted ? permission.request().catchAndReturn(()) : Single.just(())
                }.flatMap { interStepDelay }
            case .sensorKit:
            #if HEALTHKIT
                return result.flatMap {
                    guard let manager = Services.shared.sensorKitService as? SensorKitManager,
                                  manager.serviceAvailable
                    else { return .just(()) }

                    if granted {
                        // Ask OS -> start readers -> sync
                        return manager.requestPermissions()
                            .do(onSuccess: {
                                manager.ensureRecordingStarted()
                                manager.triggerSync(reason: "optin")
                            })
                            .catchAndReturn(())
                    } else {
                        manager.refreshRecordingBasedOnClearance()
                        return .just(())
                    }
                }.flatMap { interStepDelay }
            #else
                return .just(())
            #endif
            }
        }
        
        systemPermissionRequests
            .flatMap { self.repository.sendOptInPermission(permission: optInPermission, granted: granted) }
            .addProgress()
            .subscribe(onSuccess: { [weak self] () in
                guard let self = self else { return }
                
                guard let permissionIndex = self.sectionData.optInPermissions.firstIndex(where: { $0.id == optInPermission.id }) else {
                    assertionFailure("Missing Permission with give ID")
                    return
                }
                
                let nextPermissionIndex = permissionIndex + 1
                if nextPermissionIndex < self.sectionData.optInPermissions.count {
                    self.showOptInPermission(self.sectionData.optInPermissions[nextPermissionIndex])
                } else {
                    self.showSuccess()
                }
            }, onFailure: { [weak self] error in
                guard let self = self else { return }
                self.navigator.handleError(error: error, presenter: self.navigationController)
            }).disposed(by: self.disposeBag)
    }
}
