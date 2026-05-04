//
//  LoadingViewController.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 24/04/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import UIKit
import RxSwift

protocol LoadingPage {}

enum LoadingMode<T> {
    case initialSetup
    case genericLoad(loadingInfo: LoadingInfo<T>, allowBack: Bool)
}

struct LoadingInfo<T> {
    typealias CompletionCallback = ((T) -> Void)
    
    let requestSingle: Single<T>
    let completionCallback: CompletionCallback
}

class LoadingViewController<T>: UIViewController, LoadingPage {
    
    private let loadingMode: LoadingMode<T>
    private let navigator: AppNavigator
    
    private let disposeBag = DisposeBag()
    
    private lazy var errorView: GenericErrorView = {
        return GenericErrorView(retryButtonCallback: { [weak self] in self?.startLoading() })
    }()
    
    init(loadingMode: LoadingMode<T>) {
        self.loadingMode = loadingMode
        self.navigator = Services.shared.navigator
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = ColorPalette.errorSecondaryColor
        
        self.view.addSubview(self.errorView)
        self.errorView.autoPinEdgesToSuperviewSafeArea()
        self.errorView.hideView()
        
        if let navigationController = navigationController {
            navigationController.navigationBar.apply(style: NavigationBarStyleCategory.secondary(hidden: false).style)
            switch self.loadingMode {
            case .initialSetup:
                self.navigationItem.hidesBackButton = true
            case .genericLoad(_, let allowBack):
                if allowBack {
                    self.addCustomBackButton()
                } else {
                    self.navigationItem.hidesBackButton = true
                }
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // FUAM-3021. Diagnostic trace — surfaces re-appears that re-fire
        // the underlying request (potential cause of the "spinner forever"
        // pattern observed during OurTransitions testing of v1). Cleanup
        // pass C5 removes this once OurTransitions test confirms no
        // regression.
        print("[FUAM-3021-trace] LoadingViewController.viewDidAppear -> startLoading")
        self.startLoading()
    }

    // MARK: - Private Methods

    private func startLoading() {
        print("[FUAM-3021-trace] LoadingViewController.startLoading mode=\(self.loadingMode)")
        self.errorView.hideView()
        
        switch self.loadingMode {
        case .initialSetup:
            Services.shared.initializeServices().delaySubscription(.seconds(1), scheduler: MainScheduler.instance)
                .addProgress()
                .subscribe(onNext: { progress in
                    print("SetupViewController - Initialization Progress: \(progress)")
                }, onError: { [weak self] error in
                    guard let self = self else { return }
                    self.errorView.showViewWithError(error)
                }, onCompleted: { [weak self] in
                    guard let self = self else { return }
                    self.navigator.showSetupCompleted()
                }).disposed(by: self.disposeBag)
            
        case .genericLoad(let loadingInfo, _):
            loadingInfo.requestSingle
                .addProgress()
                .subscribe(onSuccess: { loadedData in
                    loadingInfo.completionCallback(loadedData)
                }, onFailure: { [weak self]  error in
                    guard let self = self else { return }
                    if false == self.navigator.handleUserNotLoggedError(error: error) {
                        self.errorView.showViewWithError(error)
                    }
                }).disposed(by: self.disposeBag)
        }
    }
}
