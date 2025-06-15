//
//  EatenEntryFormViewController.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 15/06/25.
//

import UIKit
import PureLayout

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
        didSet { proteinValueLabel.text = (selectedProtein == true ? "Yes" : "No") }
    }

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

    private let datePromptLabel: UILabel = {
        let lbl = UILabel()
        lbl.text = "Specify the date and time of your meal."
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

    private let quantityLabel: UILabel = {
        let lbl = UILabel()
        lbl.text = "Was your meal ..."
        lbl.font = FontPalette.fontStyleData(forStyle: .paragraphBold).font
        lbl.numberOfLines = 0
        return lbl
    }()
    private let quantityValueLabel: UILabel = createValueLabel()
    private let quantityRow: UIControl = createRowControl()

    private let proteinLabel: UILabel = {
        let lbl = UILabel()
        lbl.text = "Did your meal contain significant protein/fiber/fat?"
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
        scrollStackView.stackView.addLabel(attributedString: header, numberOfLines: 1)
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
}
