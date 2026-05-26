//
//  HotFlashCoordinator.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 23/04/26.
//

import UIKit
import RxSwift

final class HotFlashCoordinator {

    private let repository: Repository
    private let navigator: AppNavigator
    private let variant: FlowVariant
    private let completionCallback: NotificationCallback
    private let disposeBag = DisposeBag()

    private var eventDate: Date?
    private var rootNavigationController: UINavigationController?

    // FUAM-3247 — accumulated answers across the 4 additional steps. Stay
    // `nil` when the extended flow is disabled by config so the legacy
    // payload shape (no `data`) is preserved on submit.
    private var severity: [String]?
    private var duration: String?
    private var symptoms: [String]?
    private var sleepOnset: String?

    init(repository: Repository,
         navigator: AppNavigator,
         variant: FlowVariant,
         completion: @escaping NotificationCallback) {
        self.repository = repository
        self.navigator = navigator
        self.variant = variant
        self.completionCallback = completion
    }

    func getStartingPage() -> UIViewController {
        let timeVC = HotFlashTimeViewController(variant: variant)
        timeVC.delegate = self
        let nav = UINavigationController(rootViewController: timeVC)
        self.rootNavigationController = nav
        return nav
    }

    /// FUAM-3247: returns true when the study config carries at least the
    /// Severity title — used as a single feature-flag probe to decide whether
    /// to push the 4 extra screens or to submit straight after DateTime.
    private var additionalStepsEnabled: Bool {
        !StringsProvider.string(forKey: .hotFlashSeverityTitle).isEmpty
    }

    private func proceedAfterDateChosen() {
        if additionalStepsEnabled {
            pushSeverityStep()
        } else {
            submit()
        }
    }

    private func submit() {
        guard let date = self.eventDate else { return }
        let data = DiaryNoteHotFlashData(
            date: date,
            fromChart: variant.isFromChart,
            diaryNote: variant.chartDiaryNote,
            severity: severity,
            duration: duration,
            symptoms: symptoms,
            sleepOnset: sleepOnset
        )
        self.repository.sendDiaryNoteHotFlash(data: data)
            .addProgress()
            .subscribe(onSuccess: { [weak self] note in
                self?.showSuccessPage(diaryNote: note)
            }, onFailure: { [weak self] error in
                guard let self = self, let presenter = self.rootNavigationController else { return }
                self.navigator.handleError(error: error, presenter: presenter)
            }).disposed(by: self.disposeBag)
    }

    private func showSuccessPage(diaryNote: DiaryNoteItem) {
        let vc = HotFlashSuccessViewController(diaryNote: diaryNote,
                                               completion: self.completionCallback)
        vc.modalPresentationStyle = .fullScreen
        self.rootNavigationController?.pushViewController(vc, animated: true)
    }

    // MARK: - Additional steps (FUAM-3247)

    private func pushStep(_ vc: HotFlashOptionsStepViewController) {
        vc.delegate = self
        self.rootNavigationController?.pushViewController(vc, animated: true)
    }

    private func pushSeverityStep() {
        let vc = HotFlashOptionsStepViewController(
            title: StringsProvider.string(forKey: .hotFlashSeverityTitle),
            message: optionalText(.hotFlashSeverityMessage),
            options: [
                .init(code: "warm",             label: StringsProvider.string(forKey: .hotFlashSeverityOptionWarm)),
                .init(code: "hot",              label: StringsProvider.string(forKey: .hotFlashSeverityOptionHot)),
                .init(code: "sweating",         label: StringsProvider.string(forKey: .hotFlashSeverityOptionSweating)),
                .init(code: "cold_chill_after", label: StringsProvider.string(forKey: .hotFlashSeverityOptionColdChill)),
                .init(code: "not_sure",         label: StringsProvider.string(forKey: .hotFlashSeverityOptionNotSure))
            ],
            mode: .multi,
            nextButtonText: StringsProvider.string(forKey: .diaryNoteHotFlashNextButton)
        )
        pushStep(vc)
    }

    private func pushDurationStep() {
        let vc = HotFlashOptionsStepViewController(
            title: StringsProvider.string(forKey: .hotFlashDurationTitle),
            message: optionalText(.hotFlashDurationMessage),
            options: [
                .init(code: "less_than_a_minute",    label: StringsProvider.string(forKey: .hotFlashDurationOptionLessThanMinute)),
                .init(code: "one_to_two_minutes",    label: StringsProvider.string(forKey: .hotFlashDurationOptionOneToTwo)),
                .init(code: "two_to_three_minutes",  label: StringsProvider.string(forKey: .hotFlashDurationOptionTwoToThree)),
                .init(code: "nearly_five_minutes",   label: StringsProvider.string(forKey: .hotFlashDurationOptionNearlyFive)),
                .init(code: "not_sure",              label: StringsProvider.string(forKey: .hotFlashDurationOptionNotSure))
            ],
            mode: .single,
            nextButtonText: StringsProvider.string(forKey: .diaryNoteHotFlashNextButton)
        )
        pushStep(vc)
    }

    private func pushSymptomsStep() {
        let vc = HotFlashOptionsStepViewController(
            title: StringsProvider.string(forKey: .hotFlashSymptomsTitle),
            message: optionalText(.hotFlashSymptomsMessage),
            options: [
                .init(code: "none",                label: StringsProvider.string(forKey: .hotFlashSymptomsOptionNone)),
                .init(code: "anxiety",             label: StringsProvider.string(forKey: .hotFlashSymptomsOptionAnxiety)),
                .init(code: "panic",               label: StringsProvider.string(forKey: .hotFlashSymptomsOptionPanic)),
                .init(code: "racing_thoughts",     label: StringsProvider.string(forKey: .hotFlashSymptomsOptionRacingThoughts)),
                .init(code: "heart_palpitations", label: StringsProvider.string(forKey: .hotFlashSymptomsOptionHeartPalpitations)),
                .init(code: "cognitive_symptoms", label: StringsProvider.string(forKey: .hotFlashSymptomsOptionCognitive)),
                .init(code: "not_sure",            label: StringsProvider.string(forKey: .hotFlashSymptomsOptionNotSure))
            ],
            mode: .multi,
            nextButtonText: StringsProvider.string(forKey: .diaryNoteHotFlashNextButton)
        )
        pushStep(vc)
    }

    private func pushSleepOnsetStep() {
        let vc = HotFlashOptionsStepViewController(
            title: StringsProvider.string(forKey: .hotFlashSleepOnsetTitle),
            message: optionalText(.hotFlashSleepOnsetMessage),
            options: [
                .init(code: "awake_with_sensation", label: StringsProvider.string(forKey: .hotFlashSleepOnsetOptionBeforeWake)),
                .init(code: "awake_then_sensation", label: StringsProvider.string(forKey: .hotFlashSleepOnsetOptionAfterWake)),
                .init(code: "not_sure",             label: StringsProvider.string(forKey: .hotFlashSleepOnsetOptionNotSure))
            ],
            mode: .single,
            nextButtonText: StringsProvider.string(forKey: .diaryNoteHotFlashNextButton)
        )
        pushStep(vc)
    }

    /// Returns the string for the key only if it's non-empty — used for the
    /// optional message under each step's title, so the layout collapses
    /// cleanly when the study doesn't supply a message.
    private func optionalText(_ key: StringKey) -> String? {
        let text = StringsProvider.string(forKey: key)
        return text.isEmpty ? nil : text
    }
}

extension HotFlashCoordinator: HotFlashTimeViewControllerDelegate {
    func hotFlashTimeViewController(_ vc: HotFlashTimeViewController,
                                    didSelect relative: HotFlashTimeViewController.TimeRelative) {
        switch relative {
        case .justNow:
            self.eventDate = Date()
            self.proceedAfterDateChosen()
        case .inThePast:
            let dateVC = HotFlashDateTimeViewController(variant: variant)
            dateVC.delegate = self
            self.rootNavigationController?.pushViewController(dateVC, animated: true)
        }
    }

    func hotFlashTimeViewControllerDidDismiss(_ vc: HotFlashTimeViewController) {
        self.completionCallback()
    }
}

extension HotFlashCoordinator: HotFlashDateTimeViewControllerDelegate {
    func hotFlashDateTimeViewController(_ vc: HotFlashDateTimeViewController, didSelect date: Date) {
        self.eventDate = date
        self.proceedAfterDateChosen()
    }

    func hotFlashDateTimeViewControllerDidCancel(_ vc: HotFlashDateTimeViewController) {
        self.completionCallback()
    }
}

// MARK: - HotFlashOptionsStepViewControllerDelegate (FUAM-3247)

extension HotFlashCoordinator: HotFlashOptionsStepViewControllerDelegate {

    /// Sequential step machine driven by which property is still `nil`. The
    /// expected push order is Severity → Duration → Symptoms → SleepOnset,
    /// matching FUAM-3245's flow.
    func hotFlashOptionsStepViewController(_ vc: HotFlashOptionsStepViewController,
                                           didConfirm selected: [String]) {
        if self.severity == nil {
            self.severity = selected
            pushDurationStep()
        } else if self.duration == nil {
            self.duration = selected.first
            pushSymptomsStep()
        } else if self.symptoms == nil {
            self.symptoms = selected
            pushSleepOnsetStep()
        } else if self.sleepOnset == nil {
            self.sleepOnset = selected.first
            submit()
        }
    }

    func hotFlashOptionsStepViewControllerDidCancel(_ vc: HotFlashOptionsStepViewController) {
        self.completionCallback()
    }
}
