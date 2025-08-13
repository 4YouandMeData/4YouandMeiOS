//
//  EatenEntryFormViewController.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 15/06/25.
//

import UIKit
import RxSwift

/// ViewController for "I've eaten..." form (read-only mode)
class EatenEntryFormViewController: UIViewController {

    // MARK: - State
    private var diaryNote: DiaryNoteItem?
    private var selectedMealType: FoodEntryType? {
        didSet { mealTypeValueLabel.text = selectedMealType?.displayTextUsingVariant(variant: .standalone) }
    }
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
    private var selectedQuantity: ConsumptionQuantity? {
        didSet { quantityValueLabel.text = selectedQuantity?.displayTextUsingVariant(variant: .standalone) }
    }
    private var selectedProtein: Bool? {
        didSet { proteinValueLabel.text = (selectedProtein == true
                                           ? StringsProvider.string(forKey: .diaryNoteEatenStepFifthFirstButton)
                                           : StringsProvider.string(forKey: .diaryNoteEatenStepFifthSecondButton))
        }
    }
    
    private var selectedEmoji: EmojiItem?
    private let repository: Repository = Services.shared.repository
    private let navigator: AppNavigator = Services.shared.navigator
    private var cache: CacheService = Services.shared.storageServices
    private let disposeBag = DisposeBag()
    
    private lazy var emojiButton: UIButton = {
        let button = UIButton()
        button.setImage(ImagePalette.image(withName: .emojiICon), for: .normal)
        button.tintColor = ColorPalette.color(withType: .primaryText)
        button.autoSetDimensions(to: CGSize(width: 24, height: 24))
        button.addTarget(self, action: #selector(emojiButtonTapped), for: .touchUpInside)
        return button
    }()

    // MARK: - Subviews
    private let scrollStackView = ScrollStackView(axis: .vertical, horizontalInset: 16)

    private let mealTypeLabel: UILabel = {
        let lbl = UILabel()
        lbl.text = StringsProvider.string(forKey: .diaryNoteEatenStepOneMessage)
        lbl.font = FontPalette.fontStyleData(forStyle: .paragraphBold).font
        lbl.numberOfLines = 0
        return lbl
    }()
    private let mealTypeValueLabel: UILabel = createValueLabel()
    private let mealTypeRow: UIControl = createRowControl()

    private lazy var datePromptLabel: UILabel = {
        let lbl = UILabel()
        let messageKey = StringsProvider.string(forKey: .diaryNoteEatenStepThreeMessage)
            .replacingPlaceholders(with: [selectedMealType?.displayTextUsingVariant(variant: .standalone).lowercased() ?? ""])
    
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .left
        
        let attrsNormal: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 17),
            .foregroundColor: ColorPalette.color(withType: .primaryText),
            .paragraphStyle: paragraph
        ]

        let attributed = NSMutableAttributedString(string: messageKey, attributes: attrsNormal)

        let attrsBold: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 17),
            .foregroundColor: ColorPalette.color(withType: .primaryText),
            .paragraphStyle: paragraph
        ]

        // Find the range of the string to be bolded
        if let boldRange = messageKey.range(of: messageKey) {
            let nsRange = NSRange(boldRange, in: messageKey)
            attributed.addAttributes(attrsBold, range: nsRange)
        }
        lbl.attributedText = attributed
        lbl.font = FontPalette.fontStyleData(forStyle: .paragraphBold).font
        lbl.numberOfLines = 0
        return lbl
    }()
    private let dateValueLabel: UILabel = createValueLabel()
    private let dateRow: UIControl = createRowControl()
    private let datePicker: UIDatePicker = {
        let dp = UIDatePicker()
        dp.datePickerMode = .dateAndTime
        dp.preferredDatePickerStyle = .inline
        dp.maximumDate = Date()
        dp.isHidden = true
        return dp
    }()

    private lazy var quantityLabel: UILabel = {
        let lbl = UILabel()
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .left
        let messageKey = StringsProvider.string(forKey: .diaryNoteEatenStepFourthMessage)
            .replacingPlaceholders(with: [selectedMealType?.displayTextUsingVariant(variant: .standalone).lowercased() ?? ""])
        
        let attrsNormal: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 17),
            .foregroundColor: ColorPalette.color(withType: .primaryText),
            .paragraphStyle: paragraph
        ]

        let attributed = NSMutableAttributedString(string: messageKey, attributes: attrsNormal)

        let attrsBold: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 17),
            .foregroundColor: ColorPalette.color(withType: .primaryText),
            .paragraphStyle: paragraph
        ]

        // Find the range of the string to be bolded
        if let boldRange = messageKey.range(of: messageKey) {
            let nsRange = NSRange(boldRange, in: messageKey)
            attributed.addAttributes(attrsBold, range: nsRange)
        }
        
        lbl.attributedText = attributed
        lbl.font = FontPalette.fontStyleData(forStyle: .paragraphBold).font
        lbl.numberOfLines = 0
        return lbl
    }()
    private let quantityValueLabel: UILabel = createValueLabel()
    private let quantityRow: UIControl = createRowControl()

    private lazy var proteinLabel: UILabel = {
        let lbl = UILabel()
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .left
        let messageKey = StringsProvider.string(forKey: .diaryNoteEatenStepFifthMessage)
            .replacingPlaceholders(with: [selectedMealType?.displayTextUsingVariant(variant: .standalone).lowercased() ?? ""])
        
        let attrsNormal: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 17),
            .foregroundColor: ColorPalette.color(withType: .primaryText),
            .paragraphStyle: paragraph
        ]

        let attributed = NSMutableAttributedString(string: messageKey, attributes: attrsNormal)

        let attrsBold: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 17),
            .foregroundColor: ColorPalette.color(withType: .primaryText),
            .paragraphStyle: paragraph
        ]

        // Find the range of the string to be bolded
        if let boldRange = messageKey.range(of: messageKey) {
            let nsRange = NSRange(boldRange, in: messageKey)
            attributed.addAttributes(attrsBold, range: nsRange)
        }
        
        lbl.attributedText = attributed
        lbl.font = FontPalette.fontStyleData(forStyle: .paragraphBold).font
        lbl.numberOfLines = 0
        return lbl
    }()
    private let proteinValueLabel: UILabel = createValueLabel()
    private let proteinRow: UIControl = createRowControl()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = ColorPalette.color(withType: .secondary)
        setupLayout()
        setupActions()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.secondary(hidden: false).style)
        self.addCustomBackButton()
    }

    // MARK: - Configuration
    /// Configure form with an existing diary note
    func configure(with note: DiaryNoteItem) {
        self.diaryNote = note
        populateIfNeeded()
    }

    private func populateIfNeeded() {
        guard let note = diaryNote else { return }
        
        if let payload = note.payload {
            switch payload {
            case .food(let mealType, let quantity, let significantNutrition):
                selectedMealType = FoodEntryType(rawValue: mealType)
                selectedQuantity = ConsumptionQuantity(rawValue: quantity)
                selectedProtein = significantNutrition as Bool
            default:
                fatalError("")
            }
        }
        // Date
        selectedDate = note.diaryNoteId
    }

    // MARK: - Layout
    private func setupLayout() {
        
        view.addSubview(scrollStackView)
        scrollStackView.autoPinEdgesToSuperviewSafeArea(with: .zero)
        
        let header = NSAttributedString(
            string: StringsProvider.string(forKey: .diaryNoteEatenStepOneTitle),
            attributes: [
                .font: UIFont.boldSystemFont(ofSize: FontPalette.fontStyleData(forStyle: .header2).font.pointSize),
                .foregroundColor: ColorPalette.color(withType: .primaryText),
                .paragraphStyle: {
                    let paragraph = NSMutableParagraphStyle()
                    paragraph.alignment = .center
                    return paragraph
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

        scrollStackView.stackView.addArrangedSubview(titleRow)
        scrollStackView.stackView.addBlankSpace(space: 36)

        // Meal type
        scrollStackView.stackView.addArrangedSubview(mealTypeLabel)
        scrollStackView.stackView.addBlankSpace(space: 8)
        scrollStackView.stackView.addArrangedSubview(mealTypeRow)
        mealTypeRow.addSubview(mealTypeValueLabel)
        mealTypeValueLabel.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 0,
                                                                           left: 8.0,
                                                                           bottom: 0,
                                                                           right: 0.0),
                                                        excludingEdge: .right)

        scrollStackView.stackView.addBlankSpace(space: 24)

        // Date
        scrollStackView.stackView.addArrangedSubview(datePromptLabel)
        scrollStackView.stackView.addBlankSpace(space: 8)
        scrollStackView.stackView.addArrangedSubview(dateRow)
        dateRow.addSubview(dateValueLabel)
        dateValueLabel.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 0,
                                                                       left: 8.0,
                                                                       bottom: 0,
                                                                       right: 0.0),
                                                    excludingEdge: .right)
        scrollStackView.stackView.addArrangedSubview(datePicker)

        scrollStackView.stackView.addBlankSpace(space: 24)

        // Quantity
        scrollStackView.stackView.addArrangedSubview(quantityLabel)
        scrollStackView.stackView.addBlankSpace(space: 8)
        scrollStackView.stackView.addArrangedSubview(quantityRow)
        quantityRow.addSubview(quantityValueLabel)
        quantityValueLabel.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 0,
                                                                           left: 8.0,
                                                                           bottom: 0,
                                                                           right: 0.0),
                                                        excludingEdge: .right)

        scrollStackView.stackView.addBlankSpace(space: 24)

        // Protein
        scrollStackView.stackView.addArrangedSubview(proteinLabel)
        scrollStackView.stackView.addBlankSpace(space: 8)
        scrollStackView.stackView.addArrangedSubview(proteinRow)
        proteinRow.addSubview(proteinValueLabel)
        proteinValueLabel.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 0,
                                                                          left: 8.0,
                                                                          bottom: 0,
                                                                          right: 0.0),
                                                       excludingEdge: .right)
        if let emoji = self.diaryNote?.feedbackTags?.last {
            self.selectedEmoji = emoji
            self.emojiButton.setImage(nil, for: .normal)
            self.emojiButton.setTitle(emoji.tag, for: .normal)
            self.emojiButton.titleLabel?.font = UIFont.systemFont(ofSize: 22)
        }
    }

    // MARK: - Actions (read-only)
    private func setupActions() {
        // no actions in read-only display
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
        ctrl.backgroundColor = UIColor.init(hexString: Constants.Style.FormBackgroundColor)
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
