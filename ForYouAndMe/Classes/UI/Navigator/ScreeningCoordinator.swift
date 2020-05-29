//
//  ScreeningCoordinator.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 28/05/2020.
//

import Foundation

class ScreeningCoordinator {
    
    private let sectionData: ScreeningSection
    private let completionCallback: ViewControllerCallback
    
    init(withSectionData sectionData: ScreeningSection, completionCallback: @escaping ViewControllerCallback) {
        self.sectionData = sectionData
        self.completionCallback = completionCallback
    }
    
    // MARK: - Public Methods
    
    public func getStartingPage() -> UIViewController {
        let infoPageData = InfoPageData(page: self.sectionData.welcomePage,
                                        addAbortOnboardingButton: false,
                                        confirmButtonText: nil,
                                        customConfirmButtonCallback: { [weak self] presenter in
                                            self?.showQuestions(presenter: presenter)
        })
        return InfoPageViewController(withPageData: infoPageData)
    }
    
    // MARK: - Private Methods
    
    private func showQuestions(presenter: UIViewController) {
        guard let navigationController = presenter.navigationController else {
            assertionFailure("Missing UINavigationController")
            return
        }
        let viewController = ScreeningQuestionsViewController(withQuestions: self.sectionData.questions,
                                                              successCallback: { [weak self] presenter  in
                                                                self?.showSuccess(presenter: presenter)
            },
                                                              failureCallback: { [weak self] presenter  in
                                                                self?.showFailure(presenter: presenter)
        })
        navigationController.pushViewController(viewController, animated: true)
    }
    
    private func showSuccess(presenter: UIViewController) {
        guard let navigationController = presenter.navigationController else {
            assertionFailure("Missing UINavigationController")
            return
        }
        let infoPageData = InfoPageData(page: self.sectionData.successPage,
                                        addAbortOnboardingButton: false,
                                        confirmButtonText: nil,
                                        customConfirmButtonCallback: { [weak self] presenter in
                                            self?.completionCallback(presenter)
        })
        navigationController.pushViewController(InfoPageViewController(withPageData: infoPageData), animated: true)
    }
    
    private func showFailure(presenter: UIViewController) {
        guard let navigationController = presenter.navigationController else {
            assertionFailure("Missing UINavigationController")
            return
        }
        let infoPageData = InfoPageData(page: self.sectionData.failurePage,
                                        addAbortOnboardingButton: false,
                                        confirmButtonText: StringsProvider.string(forKey: .screeningFailureRetryButton),
                                        customConfirmButtonCallback: { _ in
                                            navigationController.popViewController(animated: true)
        })
        navigationController.pushViewController(InfoPageViewController(withPageData: infoPageData), animated: true)
    }
}
