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
        self.addCustomBackButton(withImage: ImagePalette.image(withName: .backButton))
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
    
    @objc private func onboardingAbortPressed() {
        Services.shared.navigator.abortOnboarding(presenter: self)
    }
    
    func loadView<T>(requestSingle: Single<T>, viewForData: @escaping ((T) -> UIViewController)) {
        guard let navigationController = self.navigationController else {
            assertionFailure("Missing UINavigationController")
            return
        }
        let loadingInfo = LoadingInfo(requestSingle: requestSingle,
                                      completionCallback: { loadedData in
                                        let viewController = viewForData(loadedData)
                                        navigationController.pushViewController(viewController,
                                                                                animated: false,
                                                                                completion: {
                                                                                    navigationController.clearLoadingViewController()
                                        })
        })
        let loadingViewController = LoadingViewController(loadingMode: .genericLoad(loadingInfo: loadingInfo))
        navigationController.pushViewController(loadingViewController, animated: true)
    }
}
