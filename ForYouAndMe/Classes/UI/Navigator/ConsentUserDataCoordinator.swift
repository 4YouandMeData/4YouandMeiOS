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
    
    private func showUserEmailPage() {
        // TODO: Show User Email page
        print("TODO: Show User Email page")
        self.navigationController.showAlert(withTitle: "Work in progress", message: "User email page coming soon")
    }
}

extension ConsentUserDataCoordinator: UserNameCoordinator {
    func onUserNameConfirmPressed(firstName: String, lastName: String) {
        self.userFirstName = firstName
        self.userLastName = lastName
        self.showUserEmailPage()
    }
}
