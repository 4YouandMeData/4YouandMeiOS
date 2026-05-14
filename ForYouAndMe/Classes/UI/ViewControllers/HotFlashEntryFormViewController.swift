//
//  HotFlashEntryFormViewController.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 27/04/26.
//

import UIKit
import RxSwift
import PureLayout

/// ViewController for Hot Flash diary entry detail (read-only date, editable emoji)
final class HotFlashEntryFormViewController: UIViewController {

    // MARK: - State
    private var diaryNote: DiaryNoteItem?
    private var selectedDate: Date? {
        didSet {
            if let date = selectedDate {
                let fmt = DateFormatter()
                fmt.dateStyle = .short
                fmt.timeStyle = .short
                dateValueLabel.text = fmt.string(from: date)
            }
        }
    }
    private var selectedEmoji: EmojiItem?

    private let repository: Repository = Services.shared.repository
    private let navigator: AppNavigator = Services.shared.navigator
    private let cache: CacheService = Services.shared.storageServices
    private let disposeBag = DisposeBag()

    // MARK: - Subviews
    private let scrollStackView = ScrollStackView(axis: .vertical, horizontalInset: 16)

    private lazy var emojiButton: UIButton = {
        let button = UIButton()
        button.setImage(ImagePalette.image(withName: .emojiICon), for: .normal)
        button.tintColor = ColorPalette.color(withType: .primaryText)
        button.autoSetDimensions(to: CGSize(width: 24, height: 24))
        button.addTarget(self, action: #selector(emojiButtonTapped), for: .touchUpInside)
        return button
    }()

    private let datePromptLabel: UILabel = {
        let lbl = UILabel()
        lbl.text = StringsProvider.string(forKey: .diaryNoteHotFlashStepTwoMessage)
        lbl.font = FontPalette.fontStyleData(forStyle: .paragraphBold).font
        lbl.textColor = ColorPalette.color(withType: .primaryText)
        lbl.numberOfLines = 0
        return lbl
    }()

    private let dateValueLabel: UILabel = {
        let lbl = UILabel()
        lbl.font = .preferredFont(forTextStyle: .body)
        lbl.textColor = .secondaryLabel
        lbl.numberOfLines = 1
        return lbl
    }()

    private let dateRow: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(hexString: Constants.Style.FormBackgroundColor)
        view.layer.cornerRadius = 8
        view.autoSetDimension(.height, toSize: 44)
        return view
    }()

    private lazy var footerView: GenericButtonView = {
        let buttonView = GenericButtonView(withTextStyleCategory: .secondaryBackground(shadow: false))
        buttonView.setButtonText(StringsProvider.string(forKey: .diaryNoteHotFlashDetailCloseButton))
        buttonView.setButtonEnabled(enabled: true)
        buttonView.addTarget(target: self, action: #selector(closeTapped))
        return buttonView
    }()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ColorPalette.color(withType: .secondary)
        setupLayout()
        // FUAM-3247: `configure(with:)` is called by the navigator BEFORE
        // the view loads, so the stack-view children added by
        // `populateIfNeeded` would land before the date row. Re-run after
        // `setupLayout` so the additional rows append in the right order.
        populateIfNeeded()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.secondary(hidden: false).style)
        addCustomBackButton()
    }

    // MARK: - Configuration
    func configure(with note: DiaryNoteItem) {
        self.diaryNote = note
        if isViewLoaded {
            populateIfNeeded()
        }
    }

    private func populateIfNeeded() {
        guard let note = diaryNote else { return }

        if case .hotFlash(let date, let severity, let duration, let symptoms, let sleepOnset)? = note.payload {
            selectedDate = date
            // FUAM-3247: append one row per populated additional-step answer.
            // `populateIfNeeded` runs after `setupLayout`, so the date row is
            // already in the stack — these append below it.
            appendHotFlashDataRows(severity: severity,
                                   duration: duration,
                                   symptoms: symptoms,
                                   sleepOnset: sleepOnset)
        } else {
            selectedDate = note.diaryNoteId
        }

        if let emoji = note.feedbackTags?.last {
            selectedEmoji = emoji
            applyEmojiToButton(emoji)
        }
    }

    /// FUAM-3247 — render the per-field rows under the date row. A row is
    /// skipped when its value is `nil` or empty so legacy entries (`data:
    /// null`) keep showing just the date.
    private func appendHotFlashDataRows(severity: [String]?,
                                        duration: String?,
                                        symptoms: [String]?,
                                        sleepOnset: String?) {
        if let severity = severity, !severity.isEmpty {
            appendDataRow(promptKey: .hotFlashSeverityMessage,
                          value: severity.map { Self.severityLabel(forCode: $0) }.joined(separator: ", "))
        }
        if let duration = duration, !duration.isEmpty {
            appendDataRow(promptKey: .hotFlashDurationMessage,
                          value: Self.durationLabel(forCode: duration))
        }
        if let symptoms = symptoms, !symptoms.isEmpty {
            appendDataRow(promptKey: .hotFlashSymptomsMessage,
                          value: symptoms.map { Self.symptomsLabel(forCode: $0) }.joined(separator: ", "))
        }
        if let sleepOnset = sleepOnset, !sleepOnset.isEmpty {
            appendDataRow(promptKey: .hotFlashSleepOnsetMessage,
                          value: Self.sleepOnsetLabel(forCode: sleepOnset))
        }
    }

    private func appendDataRow(promptKey: StringKey, value: String) {
        scrollStackView.stackView.addBlankSpace(space: 16)

        let prompt = UILabel()
        prompt.text = StringsProvider.string(forKey: promptKey)
        prompt.font = FontPalette.fontStyleData(forStyle: .paragraphBold).font
        prompt.textColor = ColorPalette.color(withType: .primaryText)
        prompt.numberOfLines = 0
        scrollStackView.stackView.addArrangedSubview(prompt)

        scrollStackView.stackView.addBlankSpace(space: 8)

        let row = UIView()
        row.backgroundColor = UIColor(hexString: Constants.Style.FormBackgroundColor)
        row.layer.cornerRadius = 8
        row.autoSetDimension(.height, toSize: 44, relation: .greaterThanOrEqual)

        let valueLabel = UILabel()
        valueLabel.font = .preferredFont(forTextStyle: .body)
        valueLabel.textColor = .secondaryLabel
        valueLabel.numberOfLines = 0
        valueLabel.text = value

        row.addSubview(valueLabel)
        valueLabel.autoPinEdgesToSuperviewEdges(
            with: UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        )

        scrollStackView.stackView.addArrangedSubview(row)
    }

    // MARK: - FUAM-3247 code -> label mapping
    // Keep in sync with HotFlashCoordinator.push*Step() — single source of
    // truth on the wire is the BE code; the localized label here mirrors the
    // option list shown by the wizard.

    private static func severityLabel(forCode code: String) -> String {
        switch code {
        case "warm":       return StringsProvider.string(forKey: .hotFlashSeverityOptionWarm)
        case "hot":        return StringsProvider.string(forKey: .hotFlashSeverityOptionHot)
        case "sweating":   return StringsProvider.string(forKey: .hotFlashSeverityOptionSweating)
        case "cold_chill": return StringsProvider.string(forKey: .hotFlashSeverityOptionColdChill)
        case "not_sure":   return StringsProvider.string(forKey: .hotFlashSeverityOptionNotSure)
        default:           return code
        }
    }

    private static func durationLabel(forCode code: String) -> String {
        switch code {
        case "less_than_minute": return StringsProvider.string(forKey: .hotFlashDurationOptionLessThanMinute)
        case "1_to_2_minutes":   return StringsProvider.string(forKey: .hotFlashDurationOptionOneToTwo)
        case "2_to_3_minutes":   return StringsProvider.string(forKey: .hotFlashDurationOptionTwoToThree)
        case "nearly_5_minutes": return StringsProvider.string(forKey: .hotFlashDurationOptionNearlyFive)
        case "not_sure":         return StringsProvider.string(forKey: .hotFlashDurationOptionNotSure)
        default:                 return code
        }
    }

    private static func symptomsLabel(forCode code: String) -> String {
        switch code {
        case "none":               return StringsProvider.string(forKey: .hotFlashSymptomsOptionNone)
        case "anxiety":            return StringsProvider.string(forKey: .hotFlashSymptomsOptionAnxiety)
        case "panic":              return StringsProvider.string(forKey: .hotFlashSymptomsOptionPanic)
        case "racing_thoughts":    return StringsProvider.string(forKey: .hotFlashSymptomsOptionRacingThoughts)
        case "heart_palpitations": return StringsProvider.string(forKey: .hotFlashSymptomsOptionHeartPalpitations)
        case "cognitive_symptoms": return StringsProvider.string(forKey: .hotFlashSymptomsOptionCognitive)
        case "not_sure":           return StringsProvider.string(forKey: .hotFlashSymptomsOptionNotSure)
        default:                   return code
        }
    }

    private static func sleepOnsetLabel(forCode code: String) -> String {
        switch code {
        case "before_wake": return StringsProvider.string(forKey: .hotFlashSleepOnsetOptionBeforeWake)
        case "after_wake":  return StringsProvider.string(forKey: .hotFlashSleepOnsetOptionAfterWake)
        case "not_sure":    return StringsProvider.string(forKey: .hotFlashSleepOnsetOptionNotSure)
        default:            return code
        }
    }

    // MARK: - Layout
    private func setupLayout() {
        view.addSubview(scrollStackView)
        scrollStackView.autoPinEdgesToSuperviewSafeArea(with: .zero, excludingEdge: .bottom)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: FontPalette.fontStyleData(forStyle: .header2).font.pointSize),
            .foregroundColor: ColorPalette.color(withType: .primaryText),
            .paragraphStyle: paragraphStyle
        ]
        let titleLabel = UILabel()
        titleLabel.attributedText = NSAttributedString(
            string: StringsProvider.string(forKey: .diaryNoteHotFlashStepTwoTitle),
            attributes: titleAttrs
        )
        titleLabel.numberOfLines = 1

        let titleRow = UIStackView()
        titleRow.axis = .horizontal
        titleRow.alignment = .center
        titleRow.distribution = .equalSpacing
        titleRow.spacing = 8

        let leftSpacer = UIView()
        leftSpacer.autoSetDimensions(to: CGSize(width: 24, height: 24))
        if !emojiItems().isEmpty {
            titleRow.addArrangedSubview(leftSpacer)
            titleRow.addArrangedSubview(titleLabel)
            titleRow.addArrangedSubview(emojiButton)
        } else {
            titleRow.addArrangedSubview(titleLabel)
        }

        scrollStackView.stackView.addArrangedSubview(titleRow)
        scrollStackView.stackView.addBlankSpace(space: 36)

        scrollStackView.stackView.addArrangedSubview(datePromptLabel)
        scrollStackView.stackView.addBlankSpace(space: 8)

        scrollStackView.stackView.addArrangedSubview(dateRow)
        dateRow.addSubview(dateValueLabel)
        dateValueLabel.autoPinEdgesToSuperviewEdges(
            with: UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 0),
            excludingEdge: .right
        )

        view.addSubview(footerView)
        footerView.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .top)
        scrollStackView.scrollView.autoPinEdge(.bottom, to: .top, of: footerView)
    }

    // MARK: - Emoji
    private func emojiItems() -> [EmojiItem] {
        return cache.feedbackList[EmojiTagCategory.hotFlash.rawValue] ?? []
    }

    private func applyEmojiToButton(_ emoji: EmojiItem) {
        let tag = (emoji.label != "none") ? emoji.tag : nil
        emojiButton.setImage(nil, for: .normal)
        emojiButton.setTitle(tag, for: .normal)
        emojiButton.titleLabel?.font = UIFont.systemFont(ofSize: 22)
    }

    @objc private func emojiButtonTapped() {
        let items = emojiItems()
        guard !items.isEmpty else { return }

        let emojiVC = EmojiPopupViewController(
            emojis: items,
            selected: selectedEmoji
        ) { [weak self] selected in
            guard let self = self, let emoji = selected else { return }
            guard var note = self.diaryNote else { return }

            self.selectedEmoji = emoji
            if note.feedbackTags == nil {
                note.feedbackTags = []
            }
            note.feedbackTags?.append(emoji)
            self.diaryNote = note
            self.applyEmojiToButton(emoji)

            self.repository.updateDiaryNoteText(diaryNote: note)
                .addProgress()
                .subscribe(onSuccess: { },
                           onFailure: { [weak self] error in
                    guard let self = self else { return }
                    self.navigator.handleError(error: error, presenter: self)
                }).disposed(by: self.disposeBag)
        }

        emojiVC.modalPresentationStyle = .overCurrentContext
        emojiVC.modalTransitionStyle = .crossDissolve
        present(emojiVC, animated: true)
    }

    // MARK: - Actions
    @objc private func closeTapped() {
        navigationController?.popViewController(animated: true)
    }
}
