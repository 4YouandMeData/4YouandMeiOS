//
//  DosesEntryFormViewController.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 16/06/25.
//

import UIKit
import RxSwift

/// ViewController for "My doses" form (read-only)
class DosesEntryFormViewController: UIViewController {

    // MARK: - State
    private var diaryNote: DiaryNoteItem?
    private var doseType: DoseType? {
        didSet {
            doseTypeValueLabel.text = doseType?.displayText(usingVariant: .standalone)
        }
    }
    private var selectedDate: Date? {
        didSet {
            guard let date = selectedDate else { return }
            let fmt = DateFormatter()
            fmt.dateStyle = .short
            fmt.timeStyle = .short
            dateValueLabel.text = fmt.string(from: date)
        }
    }
    private var quantity: Int? {
        didSet {
            if let qty = quantity {
                quantityValueLabel.text = "\(qty) UI"
            }
        }
    }
    
    private let disposeBag = DisposeBag()
    private let repository: Repository = Services.shared.repository
    private let navigator: AppNavigator = Services.shared.navigator

    private var selectedEmoji: EmojiItem?
    private var cache: CacheService = Services.shared.storageServices
    
    private lazy var emojiButton: UIButton = {
        let button = UIButton()
        button.setImage(ImagePalette.image(withName: .emojiICon), for: .normal)
        button.tintColor = ColorPalette.color(withType: .primaryText)
        button.autoSetDimensions(to: CGSize(width: 24, height: 24))
        button.addTarget(self, action: #selector(emojiButtonTapped), for: .touchUpInside)
        return button
    }()

    // MARK: - UI Elements
    private let scrollStack = ScrollStackView(axis: .vertical, horizontalInset: 16)

    private let doseTypeLabel: UILabel = {
        let lbl = UILabel()
        lbl.text = StringsProvider.string(forKey: .doseStepOneMessage)
        lbl.font = FontPalette.fontStyleData(forStyle: .paragraphBold).font
        lbl.numberOfLines = 0
        return lbl
    }()
    private let doseTypeValueLabel: UILabel = DosesEntryFormViewController.createValueLabel()
    private let doseTypeRow: UIControl = DosesEntryFormViewController.createRowControl()

    private let dateLabel: UILabel = {
        let lbl = UILabel()
        lbl.text = StringsProvider.string(forKey: .doseStepTwoMessage)
        lbl.font = FontPalette.fontStyleData(forStyle: .paragraphBold).font
        lbl.numberOfLines = 0
        return lbl
    }()
    private let dateValueLabel: UILabel = DosesEntryFormViewController.createValueLabel()
    private let dateRow: UIControl = DosesEntryFormViewController.createRowControl()

    private let quantityLabel: UILabel = {
        let lbl = UILabel()
        lbl.text = StringsProvider.string(forKey: .doseStepTwoMessage)
        lbl.font = FontPalette.fontStyleData(forStyle: .paragraphBold).font
        lbl.numberOfLines = 0
        return lbl
    }()
    private let quantityValueLabel: UILabel = DosesEntryFormViewController.createValueLabel()
    private let quantityRow: UIControl = DosesEntryFormViewController.createRowControl()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ColorPalette.color(withType: .secondary)
        setupLayout()
        navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.secondary(hidden: false).style)
        addCustomBackButton()
    }

    // MARK: - Configuration
    func configure(with note: DiaryNoteItem) {
        self.diaryNote = note
        populate()
    }

    private func populate() {
        guard let note = diaryNote,
              let payload = note.payload else { return }
        switch payload {
        case .doses(let qty, let type):
            quantity = qty
            doseType = DoseType(rawValue: type)
        default:
            break
        }
        selectedDate = note.diaryNoteId
    }

    // MARK: - Layout
    private func setupLayout() {
        view.addSubview(scrollStack)
        scrollStack.autoPinEdgesToSuperviewSafeArea(with: .zero)

        // Title
        let header = NSAttributedString(
            string: StringsProvider.string(forKey: .doseStepOneTitle),
            attributes: [
                .font: UIFont.boldSystemFont(ofSize: FontPalette.fontStyleData(forStyle: .header2).font.pointSize),
                .foregroundColor: ColorPalette.color(withType: .primaryText),
                .paragraphStyle: {
                    let par = NSMutableParagraphStyle(); par.alignment = .center; return par
                }()
            ]
        )
        
        let titleRow = UIStackView()
        titleRow.axis = .horizontal
        titleRow.alignment = .center
        titleRow.distribution = .equalSpacing
        titleRow.spacing = 8

        let titleLabel = UILabel()
        titleLabel.attributedText = header
        titleLabel.numberOfLines = 1

        let emptyView = UIView()
        emptyView.autoSetDimensions(to: CGSize(width: 24, height: 24))

        let category = self.categoryForEmoji(diaryNote: self.diaryNote)
        if let ca = category, !self.emojiItems(for: ca).isEmpty {
            titleRow.addArrangedSubview(emptyView)
            titleRow.addArrangedSubview(titleLabel)
            titleRow.addArrangedSubview(emojiButton)
        } else {
            titleRow.addArrangedSubview(titleLabel)
        }

        scrollStack.stackView.addArrangedSubview(titleRow)
        scrollStack.stackView.addBlankSpace(space: 36)

        // Dose type
        scrollStack.stackView.addArrangedSubview(doseTypeLabel)
        scrollStack.stackView.addBlankSpace(space: 8)
        scrollStack.stackView.addArrangedSubview(doseTypeRow)
        doseTypeRow.addSubview(doseTypeValueLabel)
        doseTypeValueLabel.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 0,
                                                                           left: 8,
                                                                           bottom: 0,
                                                                           right: 0),
                                                        excludingEdge: .right)

        scrollStack.stackView.addBlankSpace(space: 24)

        // Date
        dateLabel.text = StringsProvider.string(forKey: .doseStepTwoMessage)
            .replacingPlaceholders(with: [doseType?.displayText(usingVariant: .standalone) ?? "-"])
        
        quantityLabel.text = StringsProvider.string(forKey: .doseStepTwoMessage)
            .replacingPlaceholders(with: [doseType?.displayText(usingVariant: .standalone) ?? "-"])
        
        scrollStack.stackView.addArrangedSubview(dateLabel)
        scrollStack.stackView.addBlankSpace(space: 8)
        scrollStack.stackView.addArrangedSubview(dateRow)
        dateRow.addSubview(dateValueLabel)
        dateValueLabel.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 0,
                                                                       left: 8,
                                                                       bottom: 0,
                                                                       right: 0),
                                                    excludingEdge: .right)

        scrollStack.stackView.addBlankSpace(space: 24)

        // Quantity
        scrollStack.stackView.addArrangedSubview(quantityLabel)
        scrollStack.stackView.addBlankSpace(space: 8)
        scrollStack.stackView.addArrangedSubview(quantityRow)
        quantityRow.addSubview(quantityValueLabel)
        quantityValueLabel.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 0,
                                                                           left: 8,
                                                                           bottom: 0,
                                                                           right: 0),
                                                        excludingEdge: .right)
        
        if let emoji = self.diaryNote?.feedbackTags?.last {
            self.selectedEmoji = emoji
            self.emojiButton.setImage(nil, for: .normal)
            self.emojiButton.setTitle(emoji.tag, for: .normal)
            self.emojiButton.titleLabel?.font = UIFont.systemFont(ofSize: 22)
        }
    }

    // MARK: - Helpers
    private static func createValueLabel() -> UILabel {
        let lbl = UILabel()
        lbl.font = .preferredFont(forTextStyle: .body)
        lbl.textColor = .secondaryLabel
        lbl.numberOfLines = 1
        return lbl
    }

    private static func createRowControl() -> UIControl {
        let ctrl = UIControl()
        ctrl.backgroundColor = UIColor(hexString: Constants.Style.FormBackgroundColor)
        ctrl.layer.cornerRadius = 8
        ctrl.autoSetDimension(.height, toSize: 44)
        return ctrl
    }
    
    private func emojiItems(for category: EmojiTagCategory) -> [EmojiItem] {
        return self.cache.feedbackList[category.rawValue] ?? []
    }

    private func categoryForEmoji(diaryNote: DiaryNoteItem?) -> EmojiTagCategory? {
        guard let diaryType = self.diaryNote?.diaryNoteType else {
            return Optional.none
        }
        
        switch diaryType {
        case .doses:
            return .myDoses
        case .eaten:
            return .iHaveEaten
        case .weNoticed:
            return .weHaveNoticed
        case .text, .audio, .video:
            return nil
        }
    }

    // MARK: - Actions
    @objc private func emojiButtonTapped() {
        if let category = self.categoryForEmoji(diaryNote: self.diaryNote) {
            
            let emojiItems = self.emojiItems(for: category)
            let emojiVC = EmojiPopupViewController(emojis: emojiItems,
                                                   selected: self.selectedEmoji) { [weak self] selectedEmoji in
                guard let self = self, let emoji = selectedEmoji else { return }
                guard var diaryNote = self.diaryNote else { return }
                
                self.selectedEmoji = emoji
                diaryNote.feedbackTags?.append(emoji)
                
                let tag = (emoji.label != "none") ? emoji.tag : nil
                self.emojiButton.setImage(nil, for: .normal)
                self.emojiButton.setTitle(tag, for: .normal)
                self.emojiButton.titleLabel?.font = UIFont.systemFont(ofSize: 22)
                
                self.repository.updateDiaryNoteText(diaryNote: diaryNote)
                    .addProgress()
                    .subscribe(onSuccess: { [weak self] in
                        guard let self = self else { return }
                        self.dismiss(animated: true)
                    }, onFailure: { [weak self] error in
                        guard let self = self else { return }
                        self.navigator.handleError(error: error, presenter: self)
                    }).disposed(by: self.disposeBag)
            }

            emojiVC.modalPresentationStyle = .overCurrentContext
            emojiVC.modalTransitionStyle = .crossDissolve
            self.present(emojiVC, animated: true)
        }
    }
}
