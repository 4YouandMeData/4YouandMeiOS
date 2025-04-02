//
//  ConsentUserDataSectionCoordinator.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 19/06/2020.
//

import Foundation
import RxSwift

struct UserConsentData {
    let email: String?
    let firstName: String?
    let lastName: String?
    let guardianFirstName: String?
    let guardianLastName: String?
    let relation: String?
    let signatureImage: UIImage?
    let additionalImage: UIImage?
    let isCreate: Bool
}

enum ConsentRole {
    case adult
    case minor
    case guardian
}

enum ConsentFlowStep {
    case userName(ConsentRole)
    case userEmail(ConsentRole)
    case userEmailVerification(ConsentRole)
    case userSignature(ConsentRole)
}

struct ConsentFlowConfig {
    // Adult Flow
    static let adultSteps: [ConsentFlowStep] = [
        .userName(.adult),
        .userEmail(.adult),
        .userEmailVerification(.adult),
        .userSignature(.adult)
    ]
    
    // Minor Flow
    static let minorSteps: [ConsentFlowStep] = [
        .userName(.minor),
        .userSignature(.minor),
        .userName(.guardian),
        .userEmail(.guardian),
        .userEmailVerification(.guardian),
        .userSignature(.guardian)
    ]
}

class ConsentUserDataSectionCoordinator {
    
    // MARK: - Coordinator
    var hidesBottomBarWhenPushed: Bool = false
    
    private var steps: [ConsentFlowStep]
    private var currentStepIndex: Int = 0
    
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
    private var guardianFirstName: String?
    private var guardianLastName: String?
    private var userRelation: String?
    fileprivate var userEmail: String?
    private var userSignatureImage: UIImage?
    private var additionalUserSignatureImage: UIImage?
    
    init(withSectionData sectionData: ConsentUserDataSection,
         navigationController: UINavigationController,
         completionCallback: @escaping NavigationControllerCallback) {
        self.repository = Services.shared.repository
        self.navigator = Services.shared.navigator
        self.sectionData = sectionData
        self.navigationController = navigationController
        self.completionCallback = completionCallback
        
        let isMinor = self.repository.currentUser?.userFlags.contains(where: {
            $0.name == StringsProvider.string(forKey: .onboardingMinorTag )}) ?? false
        
        self.steps = isMinor ? ConsentFlowConfig.minorSteps : ConsentFlowConfig.adultSteps
    }
    
    // MARK: - Private Methods
    
//    private func showEnterUserEmail() {
//        self.navigationController.pushViewController(UserEmailViewController(coordinator: self),
//                                                     hidesBottomBarWhenPushed: self.hidesBottomBarWhenPushed,
//                                                     animated: true)
//    }
//    
//    private func showUserEmailValidation(email: String) {
//        self.navigationController.pushViewController(UserEmailVerificationViewController(email: email, coordinator: self),
//                                                     hidesBottomBarWhenPushed: self.hidesBottomBarWhenPushed,
//                                                     animated: true)
//    }
//    
//    private func showUserDigitalSignature() {
//        self.navigationController.pushViewController(UserSignatureViewController(coordinator: self),
//                                                     hidesBottomBarWhenPushed: self.hidesBottomBarWhenPushed,
//                                                     animated: true)
//    }
    
    private func submitUserDataForMinor() {
        guard let firstName = self.userFirstName,
            let lastName = self.userLastName,
            let signatureImage = self.userSignatureImage,
            let relation = self.userRelation,
            let email = self.userEmail,
            let guardianFirstName = self.guardianFirstName,
            let guardianLastName = self.guardianLastName,
            let additionalSignature = self.additionalUserSignatureImage else {
                assertionFailure("Missing user data")
                return
        }
        
        let data = UserConsentData(
            email: email,
            firstName: firstName,
            lastName: lastName,
            guardianFirstName: guardianFirstName,
            guardianLastName: guardianLastName,
            relation: relation,
            signatureImage: signatureImage,
            additionalImage: additionalSignature,
            isCreate: true)
        
        self.repository.sendUserData(userConsentData: data)
            .flatMap { consent in
                return self.repository.sendUserDataForMinor(consentId: consent.id, userConsentData: data)
            }
            .addProgress()
            .subscribe(onSuccess: { [weak self] in
                guard let self = self else { return }
                self.showSuccess()
            }, onFailure: { [weak self] error in
                guard let self = self else { return }
                self.navigator.handleError(error: error, presenter: self.navigationController)
            })
            .disposed(by: self.disposeBag)
    }
    
    private func submitUserDataForAdult() {
        guard let firstName = self.userFirstName,
            let lastName = self.userLastName,
            let signatureImage = self.userSignatureImage else {
                assertionFailure("Missing user data")
                return
        }
        
        let data = UserConsentData(
            email: nil,
            firstName: firstName,
            lastName: lastName,
            guardianFirstName: nil,
            guardianLastName: nil,
            relation: nil,
            signatureImage: signatureImage,
            additionalImage: nil,
            isCreate: true)
        
        self.repository.sendUserData(userConsentData: data)
            .addProgress()
            .subscribe(onSuccess: { [weak self] _ in
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
    func onUserNameConfirmPressed(firstName: String,
                                  lastName: String,
                                  relation: String?,
                                  currentRole: ConsentRole) {
        
        switch currentRole {
        case .adult:
            self.userFirstName = firstName
            self.userLastName = lastName
        case .guardian:
            self.guardianFirstName = firstName
            self.guardianLastName = lastName
            self.userRelation = relation
        case .minor:
            self.userFirstName = firstName
            self.userLastName = lastName
        }
        
        self.goToNextStep()
    }
}

extension ConsentUserDataSectionCoordinator: UserEmailCoordinator {
    func onUserEmailSubmitted(email: String) {
        self.userEmail = email
        self.goToNextStep()
    }
}

extension ConsentUserDataSectionCoordinator: UserEmailVerificationCoordinator {
    func onUserEmailPressed() {
        self.navigationController.popToExpectedViewController(ofClass: UserEmailViewController.self, animated: true)
    }
    
    func onUserEmailVerified() {
//        self.showUserDigitalSignature()
        self.goToNextStep()
    }
}

extension ConsentUserDataSectionCoordinator: UserSignatureCoordinator {
    func onUserSignatureCreated(signatureImage: UIImage,
                                currentRole: ConsentRole) {
        let currentRole = currentRole
        switch currentRole {
        case .adult:
            self.userSignatureImage = signatureImage
            self.submitUserDataForAdult()
            return
        case .guardian:
            self.additionalUserSignatureImage = signatureImage
            self.submitUserDataForMinor()
            return
        case .minor:
            self.userSignatureImage = signatureImage
        }
        self.goToNextStep()
    }
    
    func onUserSignatureBackButtonPressed() {
        self.currentStepIndex -= 1
        self.navigationController.popToExpectedViewController(ofClass: UserNameViewController.self, animated: true)
    }
}

extension ConsentUserDataSectionCoordinator: PagedSectionCoordinator {
    
    var pages: [Page] { self.sectionData.pages }
    
    func getStartingPage() -> UIViewController {
        return self.steps[self.currentStepIndex].makeViewController(coordinator: self)
    }
    
    func onUnhandledPrimaryButtonNavigation(page: Page) {
        self.completionCallback(self.navigationController)
    }
    
    func goToNextStep() {
        self.currentStepIndex += 1
        
        guard self.currentStepIndex < self.steps.count else {
            self.completionCallback(self.navigationController)
            return
        }
        
        let vc = self.steps[self.currentStepIndex].makeViewController(coordinator: self)
        self.navigationController.pushViewController(vc,
                                                     hidesBottomBarWhenPushed: self.hidesBottomBarWhenPushed,
                                                     animated: true)
    }
}

extension ConsentFlowStep {
    
    /// Istanzia il ViewController opportuno per lo step
    func makeViewController(coordinator: ConsentUserDataSectionCoordinator) -> UIViewController {
        switch self {
        case .userName(let role):
            return UserNameViewController(coordinator: coordinator, consentRole: role)
        case .userEmail(let role):
            return UserEmailViewController(coordinator: coordinator, consentRole: role)
        case .userEmailVerification(let role):
            let email = coordinator.userEmail ?? ""
            return UserEmailVerificationViewController(email: email,
                                                       coordinator: coordinator, consentRole: role)
        case .userSignature(let role):
            return UserSignatureViewController(coordinator: coordinator, consentRole: role)
        }
    }
}
