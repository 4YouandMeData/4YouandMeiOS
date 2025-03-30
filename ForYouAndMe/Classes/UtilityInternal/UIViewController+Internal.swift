//
//  UIViewController+Internal.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 22/05/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import Foundation
import RxSwift

extension UIViewController {
    
    func addCustomBackButton() {
        self.addCustomBackButton(withImage: ImagePalette.templateImage(withName: .backButtonNavigation))
    }
    
    func addCustomCloseButton() {
        self.addCustomCloseButton(withImage: ImagePalette.templateImage(withName: .closeButton))
    }
    
    func addOnboardingAbortButton(withColor color: UIColor) {
        assert(self.navigationController != nil, "Missing UINavigationController")
        let buttonItem = UIBarButtonItem(title: StringsProvider.string(forKey: .onboardingAbortButton),
                                         style: .plain,
                                         target: self,
                                         action: #selector(self.onboardingAbortPressed))
        buttonItem.setTitleTextAttributes([
            .foregroundColor: color,
            .font: FontPalette.fontStyleData(forStyle: .header3).font
            ], for: .normal)
        self.navigationItem.rightBarButtonItem = buttonItem
    }
    
    func handleDeeplinks(deeplinkService: DeeplinkService,
                         navigator: AppNavigator,
                         repository: Repository,
                         disposeBag: DisposeBag) {
        if let deeplink = deeplinkService.currentDeeplink {
            switch deeplink {
            case .openTask(let taskId):
                repository.getTask(taskId: taskId)
                    .subscribe(onSuccess: { feed in
                        navigator.startFeedFlow(withFeed: feed, presenter: self)
                    }, onFailure: { error in
                        print("\(Self.self) - Could not get task for deeplink. Error: \(error)")
                    }).disposed(by: disposeBag)
            case .openUrl(let url):
                navigator.openUrlOnBrowser(url, presenter: self)
            case .openIntegrationApp(let integrationName):
                if let oAuthIntegration = IntegrationProvider.oAuthIntegration(withName: integrationName) {
                    navigator.openIntegrationApp(forIntegration: oAuthIntegration)
                }
            }
            deeplinkService.clearCurrentDeeplinkedData()
        }
    }
    
    // MARK: - actions
    
    @objc private func onboardingAbortPressed() {
        Services.shared.navigator.abortOnboardingWithWarning(presenter: self)
    }
}
