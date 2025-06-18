//
//  WeHaveNoticedEntryFormViewController.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 16/06/25.
//

import UIKit
import PureLayout

/// ViewController per il form “We’ve noticed…” in sola lettura
class WeHaveNoticedEntryFormViewController: UIViewController {

    // MARK: - State
    private var diaryNote: DiaryNoteItem?
    private var physicalActivity: ActivityLevel?
    private var oldValue: Double?
    private var currentValue: Double?
    private var oldValueRetrievedAt: Date?
    private var currentValueRetrievedAt: Date?
    private var stressLevel: StressLevel?
    private var injected: Bool = false
    private var injectionType: DoseType?
    private var injectionQuantity: Int?
    private var ateInPriorHour: Bool = false
    private var ateType: FoodEntryType?
    private var ateDate: Date?
    private var ateQuantity: ConsumptionQuantity?
    private var ateFat: Bool?

    // MARK: - UI
    private let scrollStackView = ScrollStackView(axis: .vertical, horizontalInset: 16)
    private let descriptionLabel = UILabel.createParagraphLabel(text: "")

    // Injection Views
    private let injectedLabel = UILabel.createBoldParagraphLabel(text: StringsProvider.string(forKey: .noticedStepOneMessage))
    private let injectedRow = UIControl.createValueRow()
    private let injectionTypeLabel = UILabel.createBoldParagraphLabel(text: StringsProvider.string(forKey: .noticedStepTwoMessage))
    private let injectionTypeRow = UIControl.createValueRow()
    private let injectionQuantityLabel = UILabel.createBoldParagraphLabel(text: "")
    private let injectionQuantityRow = UIControl.createValueRow()

    // Eating Views
    private let ateLabel = UILabel.createBoldParagraphLabel(text: StringsProvider.string(forKey: .noticedStepFourMessage))
    private let ateRow = UIControl.createValueRow()
    private let ateTypeLabel = UILabel.createBoldParagraphLabel(text: StringsProvider.string(forKey: .noticedStepFiveMessage))
    private let ateTypeRow = UIControl.createValueRow()
    private let ateDateLabel = UILabel.createBoldParagraphLabel(text: StringsProvider.string(forKey: .noticedStepSevenMessage))
    private let ateDateRow = UIControl.createValueRow()
    private let ateQuantityLabel = UILabel.createBoldParagraphLabel(text: StringsProvider.string(forKey: .noticedStepEightMessage))
    private let ateQuantityRow = UIControl.createValueRow()
    private let ateFatLabel = UILabel.createBoldParagraphLabel(text: StringsProvider.string(forKey: .noticedStepNineMessage))
    private let ateFatRow = UIControl.createValueRow()

    // Noticed – physical & stress
    private let activityLabel = UILabel.createBoldParagraphLabel(text: StringsProvider.string(forKey: .noticedStepTenMessage))
    private let activityRow = UIControl.createValueRow()
    private let stressLabel = UILabel.createBoldParagraphLabel(text: StringsProvider.string(forKey: .noticedStepElevenMessage))
    private let stressRow = UIControl.createValueRow()

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
        guard case let .noticed(
            physicalActivity,
            oldValue,
            currentValue,
            oldValueRetrievedAt,
            currentValueRetrievedAt,
            stressLevel,
            injected,
            injectionType,
            injectionQuantity,
            ateInPriorHour,
            ateType,
            ateDate,
            ateQuantity,
            ateFat
        ) = note.payload else {
            return
        }
        // Assign state
        self.physicalActivity = ActivityLevel(rawValue: physicalActivity)
        self.oldValue = oldValue
        self.currentValue = currentValue
        self.oldValueRetrievedAt = oldValueRetrievedAt
        self.currentValueRetrievedAt = currentValueRetrievedAt
        self.stressLevel = StressLevel(rawValue: stressLevel)
        self.injected = injected ?? false
        self.injectionType = injectionType.flatMap { DoseType(rawValue: $0) }
        self.injectionQuantity = injectionQuantity
        self.ateInPriorHour = ateInPriorHour ?? false
        self.ateType = ateType.flatMap { FoodEntryType(rawValue: $0) }
        self.ateDate = ateDate
        self.ateQuantity = ateQuantity.flatMap { ConsumptionQuantity(rawValue: $0) }
        self.ateFat = ateFat

        populateFields()
    }

    private func populateFields() {
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        timeFormatter.dateStyle = .none
        
        let dateTimeFormatter = DateFormatter()
        dateTimeFormatter.dateStyle = .short
        dateTimeFormatter.timeStyle = .short

        // Description
        if let oldV = oldValue,
           let newV = currentValue,
           let oldD = oldValueRetrievedAt,
           let newD = currentValueRetrievedAt {
            let from = dateTimeFormatter.string(from: oldD)
            let to = dateTimeFormatter.string(from: newD)
            descriptionLabel.text = StringsProvider.string(forKey: .weHaveNoticedMessage)
                .replacingPlaceholders(with: ["\(Int(oldV))", from, "\(Int(newV))", to])
            descriptionLabel.textAlignment = .center
        }

        // Injection
        if let label = injectedRow.subviews.compactMap({ $0 as? UILabel }).first {
            label.text = injected
            ? StringsProvider.string(forKey: .noticedStepOneFirstButton)
            : StringsProvider.string(forKey: .noticedStepOneSecondButton)
        }
        if injected {
            if let label = injectionTypeRow.subviews.compactMap({ $0 as? UILabel }).first {
                label.text = injectionType?.displayText(usingVariant: .embeddedInNoticed) ?? "-"
            }
            if let qty = injectionQuantity,
               let label = injectionQuantityRow.subviews.compactMap({ $0 as? UILabel }).first {
                label.text = "\(qty) " + StringsProvider.string(forKey: .noticedStepThreeUnit)
            }
        }

        // Eating
        if let label = ateRow.subviews.compactMap({ $0 as? UILabel }).first {
            label.text = ateInPriorHour
            ? StringsProvider.string(forKey: .noticedStepFourFirstButton)
            : StringsProvider.string(forKey: .noticedStepFourSecondButton)
        }
        if ateInPriorHour {
            if let date = ateDate,
               let label = ateDateRow.subviews.compactMap({ $0 as? UILabel }).first {
                label.text = dateTimeFormatter.string(from: date)
            }
            if let type = ateType,
               let label = ateTypeRow.subviews.compactMap({ $0 as? UILabel}).first {
                label.text = type.displayTextUsingVariant(variant: .embeddedInNoticed)
            }
            if let qty = ateQuantity,
               let label = ateQuantityRow.subviews.compactMap({ $0 as? UILabel }).first {
                label.text = qty.displayTextUsingVariant(variant: .embeddedInNoticed)
            }
            if let fat = ateFat,
               let label = ateFatRow.subviews.compactMap({ $0 as? UILabel }).first {
                label.text = (fat)
                ? StringsProvider.string(forKey: .noticedStepNineFirstButton)
                : StringsProvider.string(forKey: .noticedStepNineSecondButton)
            }
        }

        // Physical & stress
        if let label = activityRow.subviews.compactMap({ $0 as? UILabel }).first {
            label.text = physicalActivity?.displayText ?? "-"
        }
        if let label = stressRow.subviews.compactMap({ $0 as? UILabel }).first {
            label.text = stressLevel?.displayText ?? "-"
        }
    }

    // MARK: - Layout
    private func setupLayout() {
        view.addSubview(scrollStackView)
        scrollStackView.autoPinEdgesToSuperviewSafeArea(with: .zero)

        // Titolo
        let header = NSAttributedString(
            string: StringsProvider.string(forKey: .noticedStepOneTitle),
            attributes: [
                .font: UIFont.boldSystemFont(ofSize: FontPalette.fontStyleData(forStyle: .header2).font.pointSize),
                .foregroundColor: ColorPalette.color(withType: .primaryText),
                .paragraphStyle: { let ps = NSMutableParagraphStyle(); ps.alignment = .center; return ps }()
            ]
        )
        scrollStackView.stackView.addLabel(attributedString: header, numberOfLines: 1)
        scrollStackView.stackView.addBlankSpace(space: 24)

        // Description
        scrollStackView.stackView.addArrangedSubview(descriptionLabel)
        scrollStackView.stackView.addBlankSpace(space: 16)

        // Injection block
        if injected {
            
            self.injectionQuantityLabel.text = StringsProvider.string(forKey: .noticedStepThreeMessage)
                .replacingPlaceholders(with: [self.injectionType?.displayText(usingVariant: .embeddedInNoticed) ?? "-"])
            
            scrollStackView.stackView.addBlankSpace(space: 24)
            scrollStackView.stackView.addArrangedSubview(injectedLabel)
            scrollStackView.stackView.addBlankSpace(space: 8)
            scrollStackView.stackView.addArrangedSubview(injectedRow)
            scrollStackView.stackView.addBlankSpace(space: 16)
            scrollStackView.stackView.addArrangedSubview(injectionTypeLabel)
            scrollStackView.stackView.addBlankSpace(space: 8)
            scrollStackView.stackView.addArrangedSubview(injectionTypeRow)
            scrollStackView.stackView.addBlankSpace(space: 16)
            scrollStackView.stackView.addArrangedSubview(injectionQuantityLabel)
            scrollStackView.stackView.addBlankSpace(space: 8)
            scrollStackView.stackView.addArrangedSubview(injectionQuantityRow)
        }

        // Eating block
        if ateInPriorHour {
            
            let type = self.ateType?.displayTextUsingVariant(variant: .embeddedInNoticed)
            
            ateDateLabel.text = StringsProvider.string(forKey: .noticedStepSevenMessage)
                .replacingPlaceholders(with: [type ?? "-"])
            scrollStackView.stackView.addBlankSpace(space: injected ? 24 : 24)
            
            ateQuantityLabel.text = StringsProvider.string(forKey: .noticedStepEightMessage)
                .replacingPlaceholders(with: [type ?? "-"])
            
            ateFatLabel.text = StringsProvider.string(forKey: .noticedStepNineMessage)
                .replacingPlaceholders(with: [type ?? "-"])
            
            scrollStackView.stackView.addArrangedSubview(ateLabel)
            scrollStackView.stackView.addBlankSpace(space: 8)
            scrollStackView.stackView.addArrangedSubview(ateRow)
            scrollStackView.stackView.addBlankSpace(space: 16)
            scrollStackView.stackView.addArrangedSubview(ateTypeLabel)
            scrollStackView.stackView.addBlankSpace(space: 8)
            scrollStackView.stackView.addArrangedSubview(ateTypeRow)
            scrollStackView.stackView.addBlankSpace(space: 16)
            scrollStackView.stackView.addArrangedSubview(ateDateLabel)
            scrollStackView.stackView.addBlankSpace(space: 8)
            scrollStackView.stackView.addArrangedSubview(ateDateRow)
            scrollStackView.stackView.addBlankSpace(space: 16)
            scrollStackView.stackView.addArrangedSubview(ateQuantityLabel)
            scrollStackView.stackView.addBlankSpace(space: 8)
            scrollStackView.stackView.addArrangedSubview(ateQuantityRow)
            scrollStackView.stackView.addBlankSpace(space: 16)
            scrollStackView.stackView.addArrangedSubview(ateFatLabel)
            scrollStackView.stackView.addBlankSpace(space: 8)
            scrollStackView.stackView.addArrangedSubview(ateFatRow)
        }

        // Noticed physics & stress
        scrollStackView.stackView.addBlankSpace(space: (injected || ateInPriorHour) ? 24 : 24)
        scrollStackView.stackView.addArrangedSubview(activityLabel)
        scrollStackView.stackView.addBlankSpace(space: 8)
        scrollStackView.stackView.addArrangedSubview(activityRow)
        scrollStackView.stackView.addBlankSpace(space: 16)
        scrollStackView.stackView.addArrangedSubview(stressLabel)
        scrollStackView.stackView.addBlankSpace(space: 8)
        scrollStackView.stackView.addArrangedSubview(stressRow)
    }
}

// MARK: - Helpers: Extensions for creating labels and rows
private extension UILabel {
    static func createParagraphLabel(text: String) -> UILabel {
        let lbl = UILabel()
        lbl.text = text
        lbl.numberOfLines = 0
        lbl.font = FontPalette.fontStyleData(forStyle: .paragraph).font
        lbl.textColor = ColorPalette.color(withType: .primaryText)
        return lbl
    }

    static func createBoldParagraphLabel(text: String) -> UILabel {
        let lbl = UILabel()
        lbl.text = text
        lbl.numberOfLines = 0
        lbl.font = UIFont.boldSystemFont(ofSize: FontPalette.fontStyleData(forStyle: .paragraph).font.pointSize)
        lbl.textColor = ColorPalette.color(withType: .primaryText)
        return lbl
    }
}

private extension UIControl {
    static func createValueRow() -> UIControl {
        let ctrl = UIControl()
        ctrl.backgroundColor = UIColor(hexString: Constants.Style.FormBackgroundColor)
        ctrl.layer.cornerRadius = 8
        ctrl.autoSetDimension(.height, toSize: 44)
        let lbl = UILabel.createParagraphLabel(text: "")
        ctrl.addSubview(lbl)
        lbl.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 8))
        return ctrl
    }
}
