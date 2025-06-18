//
//  DosesEntryFormViewController.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 16/06/25.
//

import UIKit
import PureLayout

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
        scrollStack.stackView.addLabel(attributedString: header, numberOfLines: 1)
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
}
