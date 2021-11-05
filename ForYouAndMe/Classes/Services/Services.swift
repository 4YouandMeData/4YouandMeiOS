//
//  Services.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 24/04/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import UIKit
import RxSwift

protocol InitializableService {
    var isInitialized: Bool { get }
    func initialize() -> Single<()>
}

struct ServicesSetupData {
    let showDefaultUserInfo: Bool
    let enableLocationServices: Bool
    let healthReadDataTypes: [HealthDataType]
    let appleWatchAlternativeIntegrations: [Integration]
}

class Services {
    
    static let shared = Services()
    
    private var services: [Any] = []
    
    private(set) var repository: Repository!
    private(set) var navigator: AppNavigator!
    private(set) var healthService: HealthService!
    private(set) var analytics: AnalyticsService!
    private(set) var storageServices: CacheService!
    private(set) var deeplinkService: DeeplinkService!
    private(set) var deviceService: DeviceService!
    
    private var window: UIWindow?
    
    // MARK: - Public Methods
    
    func setup(withWindow window: UIWindow, servicesSetupData: ServicesSetupData) {
        self.window = window
        
        let studyId = Constants.Network.StudyId
        
        let storage = CacheManager()
        self.services.append(storage)
        
        let reachabilityService = ReachabilityManager()
        self.services.append(reachabilityService)
        
        let deeplinkService = DeeplinkManager()
        self.services.append(deeplinkService)
        
        let notificationService = NotificationManager(withNotificationDeeplinkHandler: deeplinkService)
        self.services.append(notificationService)
        
        #if DEBUG
        let networkApiGateway =
            Constants.Test.NetworkStubsEnabled
                ? TestNetworkApiGateway(studyId: studyId, reachability: reachabilityService, storage: storage)
                : NetworkApiGateway(studyId: studyId, reachability: reachabilityService, storage: storage)
        #else
        let networkApiGateway = NetworkApiGateway(studyId: studyId, reachability: reachabilityService, storage: storage)
        #endif
        self.services.append(networkApiGateway)
        
        let analytics = AnalyticsManager(api: networkApiGateway)
        self.services.append(analytics)
        
        #if HEALTHKIT
        let healthService = HealthManager(withReadDataTypes: servicesSetupData.healthReadDataTypes,
                                          analyticsService: analytics,
                                          storage: storage,
                                          reachability: reachabilityService)
        #else
        let healthService = DummyHealthManager()
        #endif
        services.append(healthService)
        
        let repository = RepositoryImpl(api: networkApiGateway,
                                        storage: storage,
                                        notificationService: notificationService,
                                        analyticsService: analytics,
                                        showDefaultUserInfo: servicesSetupData.showDefaultUserInfo,
                                        appleWatchAlternativeIntegrations: servicesSetupData.appleWatchAlternativeIntegrations)
        self.services.append(repository)
        
        let navigator = AppNavigator(withRepository: repository, analytics: analytics, deeplinkService: deeplinkService, window: window)
        self.services.append(navigator)
        
        let deviceService = DeviceManager(repository: repository,
                                          locationServicesAvailable: servicesSetupData.enableLocationServices,
                                          storage: storage,
                                          reachability: reachabilityService)
        self.services.append(deviceService)
        
        // Add services circular dependences
        deeplinkService.delegate = navigator
        notificationService.notificationTokenDelegate = repository
        #if HEALTHKIT
        healthService.networkDelegate = repository
        healthService.clearanceDelegate = repository
        #endif
        
        // Assign concreate services
        self.repository = repository
        self.navigator = navigator
        self.healthService = healthService
        self.analytics = analytics
        self.storageServices = storage
        self.deeplinkService = deeplinkService
        self.deviceService = deviceService
        self.navigator.showSetupScreen()
    }
    
    func initializeServices() -> Observable<Float> {
        // Create an observable sequence that return the progress percentage
        // representing number of initialized services over the total initializable services
        let requests = self.services.compactMap { $0 as? InitializableService }
            .reduce([]) { (result, initializableService) -> [Single<()>] in
                var result = result
                if false == initializableService.isInitialized {
                    result.append(initializableService.initialize())
                }
                return result
        }
        
        return Observable.concat(requests.enumerated()
            .map { (index, request) in
                request.map { Float(index) / Float(requests.count) }.asObservable()
        })
    }
}
