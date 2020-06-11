//
//  ScreeningCoordinator.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 28/05/2020.
//

import Foundation

class ScreeningCoordinator: PagedSectionCoordinator {
    
    public unowned var navigationController: UINavigationController
    
    var pages: [InfoPage] { self.sectionData.pages }
    
    private let sectionData: ScreeningSection
    private let completionCallback: NavigationControllerCallback
    
    init(withSectionData sectionData: ScreeningSection,
         navigationController: UINavigationController,
         completionCallback: @escaping NavigationControllerCallback) {
        self.sectionData = sectionData
        self.navigationController = navigationController
        self.completionCallback = completionCallback
    }
    
    // MARK: - Public Methods
    
    public func getStartingPage() -> UIViewController {
        let infoPageData = InfoPageData.createWelcomePageData(withinfoPage: self.sectionData.welcomePage)
        return InfoPageViewController(withPageData: infoPageData, coordinator: self)
    }
    
    // MARK: - Private Methods
    
    private func showQuestions() {
        if self.sectionData.questions.count > 0 {
            let viewController = BooleanQuestionsViewController(withQuestions: self.sectionData.questions, coordinator: self)
            self.navigationController.pushViewController(viewController, animated: true)
        } else {
            self.completionCallback(self.navigationController)
        }
    }
    
    private func showSuccess() {
        guard let successPage = self.sectionData.successPage else {
            assertionFailure("Missing expected success page")
            return
        }
        let infoPageData = InfoPageData.createResultPageData(withinfoPage: successPage)
        let viewController = InfoPageViewController(withPageData: infoPageData, coordinator: self)
        self.navigationController.pushViewController(viewController, animated: true)
    }
    
    private func showFailure() {
        guard let failurePage = self.sectionData.failurePage else {
            assertionFailure("Missing expected failure page")
            return
        }
        let infoPageData = InfoPageData.createResultPageData(withinfoPage: failurePage)
        let viewController = InfoPageViewController(withPageData: infoPageData, coordinator: self)
        self.navigationController.pushViewController(viewController, animated: true)
    }
    
    private func popBackToQuestions() {
        guard let questionsViewController = self.navigationController.viewControllers.reversed()
            .first(where: {$0 is BooleanQuestionsViewController }) else {
                assertionFailure("Missing view controller in navigation stack")
            return
        }
        self.navigationController.popToViewController(questionsViewController, animated: true)
    }
}

extension ScreeningCoordinator: InfoPageCoordinator {
    func onInfoPagePrimaryButtonPressed(pageData: InfoPageData) {
        switch pageData.page.id {
        case self.sectionData.successPage?.id:
            self.completionCallback(self.navigationController)
        case self.sectionData.failurePage?.id:
            self.popBackToQuestions()
        default:
            if let pageRef = pageData.page.buttonFirstPage {
                self.showLinkedPage(forPageRef: pageRef, isOnboarding: true)
            } else {
                self.showQuestions()
            }
        }
    }
    func onInfoPageSecondaryButtonPressed(pageData: InfoPageData) {
        guard let pageRef = pageData.page.buttonSecondPage else {
            assertionFailure("Missing action for secondary button pressed!")
            return
        }
        self.showLinkedPage(forPageRef: pageRef, isOnboarding: true)
    }
}

extension ScreeningCoordinator: BooleanQuestionsCoordinator {
    func onBooleanQuestionsSuccess() {
        self.showSuccess()
    }
    
    func onBooleanQuestionsFailure() {
        self.showFailure()
    }
}
