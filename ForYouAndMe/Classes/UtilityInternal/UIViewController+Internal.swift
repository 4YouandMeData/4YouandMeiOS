//
//  UIViewController+Internal.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 22/05/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import Foundation

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
        buttonItem.tintColor = color
        self.navigationItem.rightBarButtonItem =  buttonItem
    }
    
    @objc private func onboardingAbortPressed() {
        Services.shared.navigator.abortOnboarding(presenter: self)
    }
}
