//
//  ConsentSectionCoordinator.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 18/06/2020.
//

import Foundation

class ConsentSectionCoordinator {
    
    // MARK: - Coordinator
    var hidesBottomBarWhenPushed: Bool = false
    
    public unowned var navigationController: UINavigationController
    
    private let sectionData: ConsentSection
    private let completionCallback: NavigationControllerCallback
    private let analytics: AnalyticsService
    
    init(withSectionData sectionData: ConsentSection,
         navigationController: UINavigationController,
         completionCallback: @escaping NavigationControllerCallback) {
        self.sectionData = sectionData
        self.navigationController = navigationController
        self.completionCallback = completionCallback
        self.analytics = Services.shared.analytics
    }
}

extension ConsentSectionCoordinator: Coordinator {
    func getStartingPage() -> UIViewController {
        let data = InfoPageListData(title: self.sectionData.title,
                                    subtitle: self.sectionData.subtitle,
                                    body: self.sectionData.body,
                                    startingPage: self.sectionData.welcomePage,
                                    pages: self.sectionData.pages,
                                    mode: .acceptance(coordinator: self))
        return InfoPageListViewController(withData: data)
    }
}

extension ConsentSectionCoordinator: AcceptanceCoordinator {
    func onAgreeButtonPressed() {
        self.analytics.track(event: .consentAgreed)
        self.completionCallback(self.navigationController)
    }
    
    func onDisagreeButtonPressed() {
        let data = PopupData(body: self.sectionData.disagreeBody,
                             buttonText: self.sectionData.disagreeButton)
        let popupViewController = PopupViewController(withData: data, coordinator: self)
        popupViewController.modalPresentationStyle = .fullScreen
        self.navigationController.present(popupViewController, animated: false, completion: nil)
    }
}

extension ConsentSectionCoordinator: PopupCoordinator {
    func onConfirmButtonPressed(popupViewController: PopupViewController) {
        popupViewController.dismiss(animated: false, completion: {
            Services.shared.navigator.abortOnboarding()
        })
    }
    
    func onCloseButtonPressed(popupViewController: PopupViewController) {
        popupViewController.dismiss(animated: false, completion: nil)
    }
}
