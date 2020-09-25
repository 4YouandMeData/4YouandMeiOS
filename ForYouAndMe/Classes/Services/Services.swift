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

class Services {
    
    static let shared = Services()
    
    private var services: [Any] = []
    
    private(set) var repository: Repository!
    private(set) var navigator: AppNavigator!
    private(set) var healthService: HealthService!
    private(set) var analytics: AnalyticsService!
    
    private var window: UIWindow?
    
    // MARK: - Public Methods
    
    func setup(withWindow window: UIWindow, studyId: String) {
        self.window = window
        
        let storage = CacheManager()
        self.services.append(storage)
        
        let healthService = HealthManager()
        services.append(healthService)
        
        let reachabilityService = ReachabilityManager()
        self.services.append(reachabilityService)
        
        #if DEBUG
        let networkApiGateway =
            Constants.Test.NetworkStubsEnabled
                ? TestNetworkApiGateway(studyId: studyId, reachability: reachabilityService, storage: storage)
                : NetworkApiGateway(studyId: studyId, reachability: reachabilityService, storage: storage)
        #else
        let networkApiGateway = NetworkApiGateway(studyId: studyId, reachability: reachabilityService, storage: storage)
        #endif
        self.services.append(networkApiGateway)
        
        let repository = RepositoryImpl(api: networkApiGateway,
                                        storage: storage)
        self.services.append(repository)
        
        let analytics = AnalyticsManager(api: networkApiGateway)
        self.services.append(analytics)
        
        let navigator = AppNavigator(withRepository: repository, analytics: analytics, window: window)
        self.services.append(navigator)
        
        // Assign concreate services
        self.repository = repository
        self.navigator = navigator
        self.healthService = healthService
        self.analytics = analytics
        
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
