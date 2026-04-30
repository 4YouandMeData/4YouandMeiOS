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

    private let dateLabel = MenstrualEntryFormViewController.makeBoldLabel(
        text: StringsProvider.string(forKey: .menstrualStepDateMessage)
    )
    private let dateRow = MenstrualEntryFormViewController.makeSingleLineValueRow()

    private let flowLabel = MenstrualEntryFormViewController.makeBoldLabel(
        text: StringsProvider.string(forKey: .menstrualStepFlowMessage)
    )
    private let flowRow = MenstrualEntryFormViewController.makeSingleLineValueRow()

    private let periodRelatedLabel = MenstrualEntryFormViewController.makeBoldLabel(
        text: StringsProvider.string(forKey: .menstrualStepPeriodMessage)
    )
    private let periodRelatedRow = MenstrualEntryFormViewController.makeMultiLineValueRow()

    private let noteLabel = MenstrualEntryFormViewController.makeBoldLabel(
        text: StringsProvider.string(forKey: .menstrualStepNoteMessage)
    )
    private let noteRow = MenstrualEntryFormViewController.makeMultiLineValueRow()

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
        self.periodRelated = MenstrualPeriodRelated(rawValue: related)
        self.note = payloadNote
        populateFields()
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
        if let related = periodRelated,
           let label = periodRelatedRow.subviews.compactMap({ $0 as? UILabel }).first {
            label.text = StringsProvider.string(forKey: related.localizedKey)
        }
        if let userNote = note,
           userNote.isEmpty == false,
           let label = noteRow.subviews.compactMap({ $0 as? UILabel }).first {
            label.text = userNote
        }

        if let emoji = diaryNote?.feedbackTags?.last {
            selectedEmoji = emoji
            applyEmojiToButton(emoji)
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

        scrollStackView.stackView.addArrangedSubview(noteLabel)
        scrollStackView.stackView.addBlankSpace(space: 8)
        scrollStackView.stackView.addArrangedSubview(noteRow)
        scrollStackView.stackView.addBlankSpace(space: 24)

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
