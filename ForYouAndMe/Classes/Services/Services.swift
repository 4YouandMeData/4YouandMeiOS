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
    
    private var window: UIWindow?
    
    private let disposeBag = DisposeBag()
    
    func setup(withWindow window: UIWindow) {
        self.window = window
        
        let storage = CacheManager()
        self.services.append(storage)
        
        let reachabilityService = ReachabilityManager()
        self.services.append(reachabilityService)
        
        #if DEBUG
        let networkApiGateway =
            Constants.Test.NetworkStubsEnabled
                ? TestNetworkApiGateway(reachability: reachabilityService)
                : NetworkApiGateway(reachability: reachabilityService)
        #else
        let networkApiGateway = NetworkApiGateway(reachability: reachabilityService)
        #endif
        self.services.append(networkApiGateway)
        
        let repository = RepositoryImpl(api: networkApiGateway,
                                        storage: storage)
        self.services.append(repository)
        
        let navigator = AppNavigator(withRepository: repository, window: window)
        self.services.append(navigator)
        
        // Assign concreate services
        self.repository = repository
        self.navigator = navigator
        
        self.initialize()
    }
    
    func initialize() {
        // Initialize services
        // TODO: Improve UI and responabilities
        self.navigator.showSetupScreen()
        self.initializeServices()
            .delaySubscription(.seconds(2), scheduler: MainScheduler.instance)
            .subscribe(onNext: { progress in
            self.navigator.showSetupProgress(progress: progress)
        }, onError: { error in
            self.navigator.showSetupError(error: error)
        }, onCompleted: {
            self.navigator.showSetupCompleted()
        }).disposed(by: self.disposeBag)
    }
    
    // MARK: - Private Methods
    
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
