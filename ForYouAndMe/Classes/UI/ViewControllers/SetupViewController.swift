//
//  SetupViewController.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 24/04/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import UIKit
import RxSwift

public class SetupViewController: UIViewController {
    
    private let navigator: AppNavigator
    private let disposeBag = DisposeBag()
    
    init() {
        self.navigator = Services.shared.navigator
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = ColorPalette.color(withType: .primary)
        
        self.navigator.pushProgressHUD()
        Services.shared.initializeServices().delaySubscription(.seconds(1), scheduler: MainScheduler.instance)
            .subscribe(onNext: { progress in
            print("SetupViewController - Initialization Progress: \(progress)")
        }, onError: { error in
            self.showError()
        }, onCompleted: {
            self.navigator.showSetupCompleted()
        }).disposed(by: self.disposeBag)
    }
    
    // MARK: - Private Methods
    
    private func showError() {
        // TODO: Implement error UI
    }
}
