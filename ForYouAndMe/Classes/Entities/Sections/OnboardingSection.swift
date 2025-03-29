//
//  OnboardingSection.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 19/11/2020.
//

import Foundation
import RxSwift

enum OnboardingSectionGroup: String, Codable {
    case introVideo = "intro_video"
    case screening = "screening"
    case consent = "consent_group"
    case integration = "integration"
    case optIn = "opt_in"
    case onboardingQuestions = "onboarding_questions"
    
    var sections: [OnboardingSection] {
        switch self {
        case .introVideo: return [.introVideo]
        case .screening: return [.screening]
        case .onboardingQuestions: return [.onboardingQuestions]
        case .consent: return [.informedConsent, .consent, .optIn, .consentUserData]
        case .integration: return [.integration]
        case .optIn: return [.optIn]
        }
    }
}

enum OnboardingSection {
    case introVideo
    case screening
    case informedConsent
    case consent
    case optIn
    case consentUserData
    case integration
    case onboardingQuestions
}

extension OnboardingSection {
    func getSyncCoordinator(withNavigationController navigationController: UINavigationController,
                            completionCallback: @escaping NavigationControllerCallback) -> Coordinator? {
        switch self {
        case .introVideo:
            return IntroVideoSectionCoordinator(withNavigationController: navigationController,
                                                completionCallback: completionCallback)
        case .onboardingQuestions, .screening, .informedConsent, .consent, .optIn, .consentUserData, .integration:
            return nil
        }
    }
    
    func getAsyncCoordinatorRequest(withNavigationController navigationController: UINavigationController,
                                    completionCallback: @escaping NavigationControllerCallback,
                                    repository: Repository) -> Single<Coordinator>? {
        switch self {
        case .introVideo:
            return nil
        case .screening:
            return repository.getScreeningSection().map { section in
                ScreeningSectionCoordinator(withSectionData: section,
                                            navigationController: navigationController,
                                            completionCallback: completionCallback)
            }
        case .onboardingQuestions:
            return repository.getOnboardingQuestionsSection().map { section in
                OnboardingQuestionsCoordinator(withSectionData: section,
                                               navigationController: navigationController,
                                               completionCallback: completionCallback)
            }
        case .informedConsent:
            return repository.getInformedConsentSection().map { section in
                InformedConsentSectionCoordinator(withSectionData: section,
                                                  navigationController: navigationController,
                                                  completionCallback: completionCallback)
            }
        case .consent:
            return repository.getConsentSection().map { section in
                ConsentSectionCoordinator(withSectionData: section,
                                          navigationController: navigationController,
                                          completionCallback: completionCallback)
            }
        case .optIn:
            return repository.getOptInSection().map { section in
                OptInSectionCoordinator(withSectionData: section,
                                        navigationController: navigationController,
                                        completionCallback: completionCallback)
            }
        case .consentUserData:
            return repository.getUserConsentSection().map { section in
                ConsentUserDataSectionCoordinator(withSectionData: section,
                                                  navigationController: navigationController,
                                                  completionCallback: completionCallback)
            }
        case .integration:
            return repository.getIntegrationSection().map { section in
                IntegrationSectionCoordinator(withSectionData: section,
                                              navigationController: navigationController,
                                              completionCallback: completionCallback)
            }
        }
    }
}
