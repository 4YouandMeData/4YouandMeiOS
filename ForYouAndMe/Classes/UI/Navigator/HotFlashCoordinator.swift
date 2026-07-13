//
//  HotFlashCoordinator.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 23/04/26.
//

import UIKit
import RxSwift

/// FUAM-3511 — authoritative identity of each of the 4 additional Hot Flash
/// option screens. Routing is bound to this identity (not to which
/// accumulator is still `nil`), so a Back→Next round-trip re-confirms the
/// same step and advances to the correct next screen with no cross-key bleed.
enum HotFlashStep: Int, CaseIterable {
    case severity
    case duration
    case symptoms
    case sleepOnset

    /// The step to push after confirming this one, or `nil` when this is the
    /// terminal step (submit fires instead). Pure, so it is unit-testable
    /// without any UI.
    var next: HotFlashStep? {
        HotFlashStep(rawValue: rawValue + 1)
    }
}

/// FUAM-3511 — pure representation of the collected answers, keyed by step.
/// Assembling the payload here (rather than inline in the coordinator) gives
/// tests a UI-free seam to drive a sequence of confirms/backs and assert the
/// resulting keys.
struct HotFlashAnswers {
    var severity: [String]?
    var duration: String?
    var symptoms: [String]?
    var sleepOnset: String?

    /// Writes `selected` into the key owned by `step`. Single-select steps
    /// keep only the first code, matching the BE contract.
    mutating func record(step: HotFlashStep, selected: [String]) {
        switch step {
        case .severity:   self.severity = selected
        case .duration:   self.duration = selected.first
        case .symptoms:   self.symptoms = selected
        case .sleepOnset: self.sleepOnset = selected.first
        }
    }
}

final class HotFlashCoordinator {

    private let repository: Repository
    private let navigator: AppNavigator
    private let variant: FlowVariant
    private let completionCallback: NotificationCallback
    private let disposeBag = DisposeBag()

    private var eventDate: Date?
    private var rootNavigationController: UINavigationController?

    // FUAM-3247 — accumulated answers across the 4 additional steps. Each key
    // stays `nil` when the extended flow is disabled by config so the legacy
    // payload shape (no `data`) is preserved on submit.
    // FUAM-3511 — answers are now keyed by the confirming step's identity, so
    // Back→Next never writes into the wrong key.
    private var answers = HotFlashAnswers()

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
            pushStep(.severity)
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
            severity: answers.severity,
            duration: answers.duration,
            symptoms: answers.symptoms,
            sleepOnset: answers.sleepOnset
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

    /// FUAM-3511 — pushes the screen for `step`, tagging the VC with the same
    /// identity so `didConfirm` routes deterministically regardless of nav
    /// history.
    private func pushStep(_ step: HotFlashStep) {
        let vc = makeStepViewController(for: step)
        vc.delegate = self
        self.rootNavigationController?.pushViewController(vc, animated: true)
    }

    private func makeStepViewController(for step: HotFlashStep) -> HotFlashOptionsStepViewController {
        switch step {
        case .severity:
            return HotFlashOptionsStepViewController(
                step: .severity,
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
        case .duration:
            return HotFlashOptionsStepViewController(
                step: .duration,
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
        case .symptoms:
            return HotFlashOptionsStepViewController(
                step: .symptoms,
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
        case .sleepOnset:
            return HotFlashOptionsStepViewController(
                step: .sleepOnset,
                title: StringsProvider.string(forKey: .hotFlashSleepOnsetTitle),
                message: optionalText(.hotFlashSleepOnsetMessage),
                options: [
                    .init(code: "awake_with_sensation", label: StringsProvider.string(forKey: .hotFlashSleepOnsetOptionBeforeWake)),
                    .init(code: "awake_then_sensation", label: StringsProvider.string(forKey: .hotFlashSleepOnsetOptionAfterWake)),
                    .init(code: "not_sure",             label: StringsProvider.string(forKey: .hotFlashSleepOnsetOptionNotSure)),
                    .init(code: "not_at_night",         label: StringsProvider.string(forKey: .hotFlashSleepOnsetOptionNotAtNight))
                ],
                mode: .single,
                nextButtonText: StringsProvider.string(forKey: .diaryNoteHotFlashNextButton)
            )
        }
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

    /// FUAM-3511 — routing is bound to the confirming `step`, never to which
    /// accumulator is still `nil`. The answer is written into the step's own
    /// key and we advance to `step.next` (or submit on the terminal step), so
    /// a Back→Next round-trip re-confirms the same step and reaches the
    /// correct next screen with no skipped step and no cross-key bleed.
    /// Push order: Severity → Duration → Symptoms → SleepOnset (FUAM-3245).
    func hotFlashOptionsStepViewController(_ vc: HotFlashOptionsStepViewController,
                                           didConfirm step: HotFlashStep,
                                           selected: [String]) {
        self.answers.record(step: step, selected: selected)
        if let nextStep = step.next {
            pushStep(nextStep)
        } else {
            submit()
        }
    }

    func hotFlashOptionsStepViewControllerDidCancel(_ vc: HotFlashOptionsStepViewController) {
        self.completionCallback()
    }
}
