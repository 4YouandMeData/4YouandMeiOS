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
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.secondary(hidden: false).style)
        addCustomBackButton()
    }

    // MARK: - Configuration
    func configure(with note: DiaryNoteItem) {
        self.diaryNote = note
        populateIfNeeded()
    }

    private func populateIfNeeded() {
        guard let note = diaryNote else { return }

        if case .hotFlash(let date)? = note.payload {
            selectedDate = date
        } else {
            selectedDate = note.diaryNoteId
        }

        if let emoji = note.feedbackTags?.last {
            selectedEmoji = emoji
            applyEmojiToButton(emoji)
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
