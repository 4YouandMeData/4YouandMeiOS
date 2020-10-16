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
        self.addCustomCloseButton(withImage: ImagePalette.image(withName: .closeButton))
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
        if let taskId = deeplinkService.getDeeplinkedTaskId() {
            repository.getTask(taskId: taskId)
                .subscribe(onSuccess: { feed in
                    navigator.startFeedFlow(withFeed: feed, presenter: self)
                    deeplinkService.clearDeeplinkedTaskData()
                }, onError: { error in
                    print("\(Self.self) - Could not get task for deeplink. Error: \(error)")
                    deeplinkService.clearDeeplinkedTaskData()
                }).disposed(by: disposeBag)
        } else if let url = deeplinkService.getDeeplinkedUrl() {
            navigator.openUrlOnBrowser(url, presenter: self)
            deeplinkService.clearDeeplinkedUrlData()
        }
    }
    
    // MARK: - actions
    
    @objc private func onboardingAbortPressed() {
        Services.shared.navigator.abortOnboardingWithWarning(presenter: self)
    }
}
