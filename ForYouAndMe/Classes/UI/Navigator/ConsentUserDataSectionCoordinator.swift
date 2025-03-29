//
//  ConsentUserDataSectionCoordinator.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 19/06/2020.
//

import Foundation
import RxSwift

class ConsentUserDataSectionCoordinator {
    
    // MARK: - Coordinator
    var hidesBottomBarWhenPushed: Bool = false
    
    // MARK: - PagedSectionCoordinator
    var addAbortOnboardingButton: Bool = true
    
    public unowned var navigationController: UINavigationController
    
    private let repository: Repository
    private let navigator: AppNavigator
    
    private let disposeBag = DisposeBag()
    
    private let sectionData: ConsentUserDataSection
    private let completionCallback: NavigationControllerCallback
    
    private var userFirstName: String?
    private var userLastName: String?
    private var userEmail: String?
    private var userSignatureImage: UIImage?
    
    init(withSectionData sectionData: ConsentUserDataSection,
         navigationController: UINavigationController,
         completionCallback: @escaping NavigationControllerCallback) {
        self.repository = Services.shared.repository
        self.navigator = Services.shared.navigator
        self.sectionData = sectionData
        self.navigationController = navigationController
        self.completionCallback = completionCallback
    }
    
    // MARK: - Private Methods
    
    private func showEnterUserEmail() {
        self.navigationController.pushViewController(UserEmailViewController(coordinator: self),
                                                     hidesBottomBarWhenPushed: self.hidesBottomBarWhenPushed,
                                                     animated: true)
    }
    
    private func showUserEmailValidation(email: String) {
        self.navigationController.pushViewController(UserEmailVerificationViewController(email: email, coordinator: self),
                                                     hidesBottomBarWhenPushed: self.hidesBottomBarWhenPushed,
                                                     animated: true)
    }
    
    private func showUserDigitalSignature() {
        self.navigationController.pushViewController(UserSignatureViewController(coordinator: self),
                                                     hidesBottomBarWhenPushed: self.hidesBottomBarWhenPushed,
                                                     animated: true)
    }
    
    private func showOnboardingQuestions() {
        self.navigationController.pushViewController(UserSignatureViewController(coordinator: self),
                                                     hidesBottomBarWhenPushed: self.hidesBottomBarWhenPushed,
                                                     animated: true)
    }
    
    private func submitUserData() {
        guard let firstName = self.userFirstName,
            let lastName = self.userLastName,
            let signatureImage = self.userSignatureImage else {
                assertionFailure("Missing user data")
                return
        }
        
        self.repository.sendUserData(firstName: firstName, lastName: lastName, signatureImage: signatureImage)
            .addProgress()
            .subscribe(onSuccess: { [weak self] in
                guard let self = self else { return }
                self.showSuccess()
            }, onFailure: { [weak self] error in
                    guard let self = self else { return }
                    self.navigator.handleError(error: error, presenter: self.navigationController)
            }).disposed(by: self.disposeBag)
    }
    
    private func showSuccess() {
        if let successPage = self.sectionData.successPage {
            self.showResultPage(successPage)
        } else {
            self.completionCallback(self.navigationController)
        }
    }
}

extension ConsentUserDataSectionCoordinator: UserNameCoordinator {
    func onUserNameConfirmPressed(firstName: String, lastName: String) {
        self.userFirstName = firstName
        self.userLastName = lastName
        self.showEnterUserEmail()
    }
}

extension ConsentUserDataSectionCoordinator: UserEmailCoordinator {
    func onUserEmailSubmitted(email: String) {
        self.userEmail = email
        self.showUserEmailValidation(email: email)
    }
}

extension ConsentUserDataSectionCoordinator: UserEmailVerificationCoordinator {
    func onUserEmailPressed() {
        self.navigationController.popToExpectedViewController(ofClass: UserEmailViewController.self, animated: true)
    }
    
    func onUserEmailVerified() {
        self.showUserDigitalSignature()
    }
}

extension ConsentUserDataSectionCoordinator: UserSignatureCoordinator {
    func onUserSignatureCreated(signatureImage: UIImage) {
        self.userSignatureImage = signatureImage
        self.submitUserData()
    }
    
    func onUserSignatureBackButtonPressed() {
        self.navigationController.popToExpectedViewController(ofClass: UserEmailViewController.self, animated: true)
    }
}

extension ConsentUserDataSectionCoordinator: PagedSectionCoordinator {
    
    var pages: [Page] { self.sectionData.pages }
    
    func getStartingPage() -> UIViewController {
        return UserNameViewController(coordinator: self)
    }
    
    func onUnhandledPrimaryButtonNavigation(page: Page) {
        self.completionCallback(self.navigationController)
    }
}
