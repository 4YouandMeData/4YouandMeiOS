//
//  ConsentUserDataCoordinator.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 19/06/2020.
//

import Foundation

class ConsentUserDataCoordinator {
    
    public unowned var navigationController: UINavigationController
    
    private let sectionData: ConsentUserDataSection
    private let completionCallback: NavigationControllerCallback
    
    private var userFirstName: String?
    private var userLastName: String?
    private var userEmail: String?
    
    init(withSectionData sectionData: ConsentUserDataSection,
         navigationController: UINavigationController,
         completionCallback: @escaping NavigationControllerCallback) {
        self.sectionData = sectionData
        self.navigationController = navigationController
        self.completionCallback = completionCallback
    }
    
    // MARK: - Public Methods
    
    public func getStartingPage() -> UIViewController {
        return UserNameViewController(coordinator: self)
    }
    
    // MARK: - Private Methods
    
    private func showEnterUserEmail() {
        self.navigationController.pushViewController(UserEmailViewController(coordinator: self), animated: true)
    }
    
    private func showUserEmailValidation(email: String) {
        // TODO: Show User Email Validation
        print("TODO: Show User Email Validation")
        self.navigationController.showAlert(withTitle: "Work in progress", message: "User email Validation coming soon")
    }
}

extension ConsentUserDataCoordinator: UserNameCoordinator {
    func onUserNameConfirmPressed(firstName: String, lastName: String) {
        self.userFirstName = firstName
        self.userLastName = lastName
        self.showEnterUserEmail()
    }
}

extension ConsentUserDataCoordinator: UserEmailCoordinator {
    func onUserEmailSubmitted(email: String) {
        self.userEmail = email
        self.showUserEmailValidation(email: email)
    }
}
