//
//  MenstrualEntryFormViewController.swift
//  ForYouAndMe
//
//  FUAM-2934 — Read-only detail screen for a single menstrual diary entry.
//  Mirrors the WeHaveNoticed/HotFlash form layout: scrolling content with
//  bold field labels + grey value rows, footer Close button.
//

import UIKit
import RxSwift
import PureLayout

final class MenstrualEntryFormViewController: UIViewController {

    // MARK: - State
    private var diaryNote: DiaryNoteItem?
    private var entryDate: Date?
    private var flowAmount: MenstrualFlowAmount?
    private var periodRelated: MenstrualPeriodRelated?
    private var periodRelatedExplanation: String?
    private var note: String?
    private var selectedEmoji: EmojiItem?

    private let repository: Repository = Services.shared.repository
    private let navigator: AppNavigator = Services.shared.navigator
    private let cache: CacheService = Services.shared.storageServices
    private let disposeBag = DisposeBag()

    // MARK: - UI
    private let scrollStackView = ScrollStackView(axis: .vertical, horizontalInset: 16)

    private lazy var emojiButton: UIButton = {
        let button = UIButton()
        button.setImage(ImagePalette.image(withName: .emojiICon), for: .normal)
        button.tintColor = ColorPalette.color(withType: .primaryText)
        button.autoSetDimensions(to: CGSize(width: 24, height: 24))
        button.addTarget(self, action: #selector(emojiButtonTapped), for: .touchUpInside)
        return button
    }()

    // Section labels mirror the wizard step questions (the Title strings) so
    // the detail screen reads as "question → answer" pairs (per Figma 729-85728).
    private let dateLabel = MenstrualEntryFormViewController.makeBoldLabel(
        text: StringsProvider.string(forKey: .menstrualStepDateTitle)
    )
    private let dateRow = MenstrualEntryFormViewController.makeSingleLineValueRow()

    private let flowLabel = MenstrualEntryFormViewController.makeBoldLabel(
        text: StringsProvider.string(forKey: .menstrualStepFlowTitle)
    )
    private let flowRow = MenstrualEntryFormViewController.makeSingleLineValueRow()

    private let periodRelatedLabel = MenstrualEntryFormViewController.makeBoldLabel(
        text: StringsProvider.string(forKey: .menstrualStepPeriodTitle)
    )
    private let periodRelatedRow = MenstrualEntryFormViewController.makeMultiLineValueRow()

    private let noteLabel = MenstrualEntryFormViewController.makeBoldLabel(
        text: StringsProvider.string(forKey: .menstrualStepNoteTitle)
    )
    private let noteRow = MenstrualEntryFormViewController.makeMultiLineValueRow()
    private let noteSection: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .fill
        stack.distribution = .fill
        stack.spacing = 0
        // Default: hidden until populateFields confirms a non-empty note.
        stack.isHidden = true
        return stack
    }()

    private lazy var footerView: GenericButtonView = {
        let buttonView = GenericButtonView(withTextStyleCategory: .secondaryBackground(shadow: false))
        buttonView.setButtonText(StringsProvider.string(forKey: .menstrualDetailCloseButton))
        buttonView.setButtonEnabled(enabled: true)
        buttonView.addTarget(target: self, action: #selector(closeTapped))
        return buttonView
    }()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ColorPalette.color(withType: .secondary)
        setupLayout()
        // configure(with:) runs before viewDidLoad (called by AppNavigator
        // before pushViewController), so populate the value rows here, after
        // the view hierarchy exists and noteSection has its default state.
        populateFields()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Close button in the footer is the only dismiss affordance — hide
        // the navigation chrome so there is no redundant back arrow.
        navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.primary(hidden: true).style)
    }

    // MARK: - Configuration
    func configure(with note: DiaryNoteItem) {
        self.diaryNote = note
        guard case let .menstrual(date, flow, related, _, payloadNote) = note.payload else {
            return
        }
        self.entryDate = date
        self.flowAmount = MenstrualFlowAmount(rawValue: flow)
        // BE returns "other" for `letMeExplain` — `init(backendValue:)` reverses
        // the mapping so the form can branch on letMeExplain to surface the
        // user-typed explanation as the field value.
        self.periodRelated = MenstrualPeriodRelated(backendValue: related)
        self.note = payloadNote
        // populateFields runs from viewDidLoad — values get applied after the
        // layout is in place. Calling it here would race with setupLayout.
    }

    private func populateFields() {
        let dateTimeFormatter = DateFormatter()
        dateTimeFormatter.dateStyle = .short
        dateTimeFormatter.timeStyle = .short

        if let date = entryDate, let label = dateRow.subviews.compactMap({ $0 as? UILabel }).first {
            label.text = dateTimeFormatter.string(from: date)
        }
        if let flow = flowAmount, let label = flowRow.subviews.compactMap({ $0 as? UILabel }).first {
            label.text = StringsProvider.string(forKey: flow.localizedKey)
        }

        // The encoder concatenates `<explanation>\n\n<finalNote>` when the user
        // picked "Let me explain" and typed both pieces. Split them back so the
        // explanation appears as the period-related answer (per Figma 729-85728)
        // and only the final note rides in the note section.
        let payloadNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        let (relatedAnswer, displayNote) = decomposeNote(payloadNote, related: periodRelated)

        if let label = periodRelatedRow.subviews.compactMap({ $0 as? UILabel }).first {
            label.text = relatedAnswer
        }

        if let displayNote = displayNote, displayNote.isEmpty == false {
            if let label = noteRow.subviews.compactMap({ $0 as? UILabel }).first {
                label.text = displayNote
            }
            noteSection.isHidden = false
        } else {
            noteSection.isHidden = true
        }

        if let emoji = diaryNote?.feedbackTags?.last {
            selectedEmoji = emoji
            applyEmojiToButton(emoji)
        }
    }

    /// Returns the text to render for the period-related answer and the
    /// remaining final-note text, depending on which branch the wizard took.
    /// - For yes/no/notSure: the answer is the localized option label and the
    ///   whole note is treated as the final note.
    /// - For letMeExplain: the explanation rides in front of the final note
    ///   separated by a blank line; if the separator is absent, the entire
    ///   stored text is treated as the explanation (final note is empty).
    private func decomposeNote(_ rawNote: String?,
                               related: MenstrualPeriodRelated?) -> (answer: String?, finalNote: String?) {
        guard let related = related else {
            return (nil, rawNote?.isEmpty == false ? rawNote : nil)
        }
        switch related {
        case .yes, .no, .notSure:
            let answer = StringsProvider.string(forKey: related.localizedKey)
            let finalNote = (rawNote?.isEmpty == false) ? rawNote : nil
            return (answer, finalNote)
        case .letMeExplain:
            guard let rawNote = rawNote, rawNote.isEmpty == false else {
                return (StringsProvider.string(forKey: related.localizedKey), nil)
            }
            if let separatorRange = rawNote.range(of: "\n\n") {
                let explanation = String(rawNote[..<separatorRange.lowerBound])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let finalNote = String(rawNote[separatorRange.upperBound...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return (explanation.isEmpty ? nil : explanation,
                        finalNote.isEmpty ? nil : finalNote)
            }
            return (rawNote, nil)
        }
    }

    // MARK: - Layout
    private func setupLayout() {
        view.addSubview(scrollStackView)
        scrollStackView.autoPinEdgesToSuperviewSafeArea(with: .zero, excludingEdge: .bottom)

        let titleLabel = UILabel()
        titleLabel.numberOfLines = 1
        titleLabel.attributedText = NSAttributedString(
            string: StringsProvider.string(forKey: .menstrualDetailTitle),
            attributes: [
                .font: UIFont.boldSystemFont(ofSize: FontPalette.fontStyleData(forStyle: .header2).font.pointSize),
                .foregroundColor: ColorPalette.color(withType: .primaryText),
                .paragraphStyle: { let ps = NSMutableParagraphStyle(); ps.alignment = .center; return ps }()
            ]
        )

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

        scrollStackView.stackView.addBlankSpace(space: 16)
        scrollStackView.stackView.addArrangedSubview(titleRow)
        scrollStackView.stackView.addBlankSpace(space: 16)

        let separator = UIView()
        separator.backgroundColor = ColorPalette.color(withType: .secondaryMenu)
        separator.autoSetDimension(.height, toSize: 1)
        scrollStackView.stackView.addArrangedSubview(separator)
        scrollStackView.stackView.addBlankSpace(space: 24)

        scrollStackView.stackView.addArrangedSubview(dateLabel)
        scrollStackView.stackView.addBlankSpace(space: 8)
        scrollStackView.stackView.addArrangedSubview(dateRow)
        scrollStackView.stackView.addBlankSpace(space: 24)

        scrollStackView.stackView.addArrangedSubview(flowLabel)
        scrollStackView.stackView.addBlankSpace(space: 8)
        scrollStackView.stackView.addArrangedSubview(flowRow)
        scrollStackView.stackView.addBlankSpace(space: 24)

        scrollStackView.stackView.addArrangedSubview(periodRelatedLabel)
        scrollStackView.stackView.addBlankSpace(space: 8)
        scrollStackView.stackView.addArrangedSubview(periodRelatedRow)
        scrollStackView.stackView.addBlankSpace(space: 24)

        // Note section is hidden when the entry has no optional note (FUAM-2934).
        // Wrapping label + spacer + row + trailing margin in a single stack lets
        // us collapse the whole block via `isHidden` without leaving a gap.
        // Visibility is toggled in populateFields based on the payload note.
        noteSection.addArrangedSubview(noteLabel)
        noteSection.addBlankSpace(space: 8)
        noteSection.addArrangedSubview(noteRow)
        noteSection.addBlankSpace(space: 24)
        scrollStackView.stackView.addArrangedSubview(noteSection)

        view.addSubview(footerView)
        footerView.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .top)
        scrollStackView.scrollView.autoPinEdge(.bottom, to: .top, of: footerView)
    }

    // MARK: - Emoji
    private func emojiItems() -> [EmojiItem] {
        return cache.feedbackList[EmojiTagCategory.menstrualCycle.rawValue] ?? []
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
        if let nav = navigationController, nav.viewControllers.first !== self {
            nav.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }
}

// MARK: - Layout helpers

private extension MenstrualEntryFormViewController {
    static func makeBoldLabel(text: String) -> UILabel {
        let lbl = UILabel()
        lbl.text = text
        lbl.numberOfLines = 0
        lbl.font = UIFont.boldSystemFont(ofSize: FontPalette.fontStyleData(forStyle: .paragraph).font.pointSize)
        lbl.textColor = ColorPalette.color(withType: .primaryText)
        return lbl
    }

    static func makeSingleLineValueRow() -> UIControl {
        let ctrl = UIControl()
        ctrl.backgroundColor = UIColor(hexString: Constants.Style.FormBackgroundColor)
        ctrl.layer.cornerRadius = 8
        ctrl.autoSetDimension(.height, toSize: 44)
        let lbl = UILabel()
        lbl.numberOfLines = 1
        lbl.font = FontPalette.fontStyleData(forStyle: .paragraph).font
        lbl.textColor = ColorPalette.color(withType: .primaryText)
        ctrl.addSubview(lbl)
        lbl.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12))
        return ctrl
    }

    static func makeMultiLineValueRow() -> UIControl {
        let ctrl = UIControl()
        ctrl.backgroundColor = UIColor(hexString: Constants.Style.FormBackgroundColor)
        ctrl.layer.cornerRadius = 8
        let lbl = UILabel()
        lbl.numberOfLines = 0
        lbl.font = FontPalette.fontStyleData(forStyle: .paragraph).font
        lbl.textColor = ColorPalette.color(withType: .primaryText)
        ctrl.addSubview(lbl)
        lbl.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12))
        return ctrl
    }
}

// MARK: - Localization keys

private extension MenstrualFlowAmount {
    var localizedKey: StringKey {
        switch self {
        case .spotting:  return .menstrualStepFlowSpotting
        case .light:     return .menstrualStepFlowLight
        case .moderate:  return .menstrualStepFlowModerate
        case .heavy:     return .menstrualStepFlowHeavy
        case .veryHeavy: return .menstrualStepFlowVeryHeavy
        }
    }
}

private extension MenstrualPeriodRelated {
    var localizedKey: StringKey {
        switch self {
        case .yes:           return .menstrualStepPeriodYes
        case .no:            return .menstrualStepPeriodNo
        case .notSure:       return .menstrualStepPeriodNotSure
        case .letMeExplain:  return .menstrualStepPeriodLetMeExplain
        }
    }
}
