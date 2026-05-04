//
//  MenstrualOnboardingCoordinator.swift
//  ForYouAndMe
//
//  FUAM-2937 — Drives the inline 2-step menstrual baseline onboarding shown
//  the first time the user taps Yes/No on the menstrual feed card. Owns its
//  modal navigation stack and reports completion via a closure so callers
//  can resume the original feed action (open wizard / save bleeding=no).
//

import UIKit
import RxSwift

final class MenstrualOnboardingCoordinator {

    /// Called when the onboarding completes successfully (settings saved).
    /// `cancelled = true` means the user backed out without finishing.
    typealias Completion = (_ cancelled: Bool) -> Void

    private let repository: Repository
    private let navigator: AppNavigator
    private let completion: Completion
    private let disposeBag = DisposeBag()

    private weak var presenter: UIViewController?
    private weak var navigationController: UINavigationController?

    private var hadPeriod3Mo: MenstrualHadPeriod3Mo?

    init(repository: Repository,
         navigator: AppNavigator,
         completion: @escaping Completion) {
        self.repository = repository
        self.navigator = navigator
        self.completion = completion
    }

    /// Present the onboarding modally over `presenter`.
    func start(from presenter: UIViewController) {
        self.presenter = presenter

        let step1 = MenstrualOnboardingPeriod3MoViewController()
        step1.delegate = self

        let nav = UINavigationController(rootViewController: step1)
        nav.modalPresentationStyle = .fullScreen
        self.navigationController = nav

        presenter.present(nav, animated: true, completion: nil)
    }

    // MARK: - Save & finish

    private func saveAndFinish(lastPeriodDate: Date?) {
        guard let hadPeriod3Mo = self.hadPeriod3Mo else {
            // Defensive: can't reach here without step 1 having selected a value.
            self.dismiss(cancelled: true)
            return
        }
        self.repository
            .sendMenstrualUserSettings(hadPeriod3Mo: hadPeriod3Mo,
                                       lastPeriodDate: lastPeriodDate)
            .addProgress()
            .subscribe(onSuccess: { [weak self] in
                self?.dismiss(cancelled: false)
            }, onFailure: { [weak self] error in
                guard let self = self else { return }
                if let presenter = self.navigationController?.topViewController {
                    self.navigator.handleError(error: error, presenter: presenter)
                }
            }).disposed(by: self.disposeBag)
    }

    private func dismiss(cancelled: Bool) {
        let completion = self.completion
        self.navigationController?.dismiss(animated: true) {
            completion(cancelled)
        }
    }
}

// MARK: - Step 1 delegate

extension MenstrualOnboardingCoordinator: MenstrualOnboardingPeriod3MoViewControllerDelegate {

    func menstrualOnboardingPeriod3MoViewController(_ vc: MenstrualOnboardingPeriod3MoViewController,
                                                    didSelect value: MenstrualHadPeriod3Mo) {
        self.hadPeriod3Mo = value
        switch value {
        case .no:
            // No → user has not had a period; skip the date step entirely.
            self.saveAndFinish(lastPeriodDate: nil)
        case .yes, .unsure:
            let step2 = MenstrualOnboardingLastPeriodViewController()
            step2.delegate = self
            self.navigationController?.pushViewController(step2, animated: true)
        }
    }

    func menstrualOnboardingPeriod3MoViewControllerDidCancel(_ vc: MenstrualOnboardingPeriod3MoViewController) {
        self.dismiss(cancelled: true)
    }
}

// MARK: - Step 2 delegate

extension MenstrualOnboardingCoordinator: MenstrualOnboardingLastPeriodViewControllerDelegate {

    func menstrualOnboardingLastPeriodViewController(_ vc: MenstrualOnboardingLastPeriodViewController,
                                                     didSelect date: Date) {
        self.saveAndFinish(lastPeriodDate: date)
    }
}
