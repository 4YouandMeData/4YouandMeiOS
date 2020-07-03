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
    
    @objc private func onboardingAbortPressed() {
        Services.shared.navigator.abortOnboardingWithWarning(presenter: self)
    }
}
