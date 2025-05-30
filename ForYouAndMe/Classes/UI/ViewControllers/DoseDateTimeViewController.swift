//
//  DoseDateTimeViewController.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 19/05/25.

//
//  DoseDateTimeViewController.swift
//  Pods
//
//  Created by [YourName] on 19/05/25.
//

import UIKit
import PureLayout

/// Protocol to notify selected date/time and dose amount or cancellation
protocol DoseDateTimeViewControllerDelegate: AnyObject {
    /// Called when user taps "Confirm" with both date and amount
    func doseDateTimeViewController(_ vc: DoseDateTimeViewController,
                                    didSelect date: Date,
                                    amount: Double)
    /// Called when user dismisses this screen (e.g. via back)
    func doseDateTimeViewControllerDidCancel(_ vc: DoseDateTimeViewController)
}

/// View controller to pick date/time and dose amount for the insulin entry
class DoseDateTimeViewController: UIViewController, UITextFieldDelegate {

    // MARK: - Public API

    /// The display text selected in the previous step
    private let displayTitle: String
    weak var delegate: DoseDateTimeViewControllerDelegate?
    private let storage: CacheService
    private let navigator: AppNavigator
    
    // MARK: - Subviews

    private let scrollStackView = ScrollStackView(
        axis: .vertical,
        horizontalInset: Constants.Style.DefaultHorizontalMargins
    )

    private let subtitleLabel: UILabel = {
        let lbl = UILabel()
        lbl.numberOfLines = 0
        return lbl
    }()

    private let sectionHeaderTime: UILabel = {
        let lbl = UILabel()
        lbl.text = StringsProvider.string(forKey: .doseStepTwoTimeLabel)
        lbl.font = FontPalette.fontStyleData(forStyle: .paragraph).font
        lbl.textColor = ColorPalette.color(withType: .primary)
        return lbl
    }()

    private let dateRow: UIControl = {
        let ctrl = UIControl()
        ctrl.backgroundColor = .clear
        return ctrl
    }()
    private let dateValueLabel: UILabel = {
        let lbl = UILabel()
        lbl.font = .preferredFont(forTextStyle: .body)
        lbl.textColor = ColorPalette.color(withType: .primaryText)
        return lbl
    }()
    private let dateIcon: UIImageView = {
        let iv = UIImageView(image: ImagePalette.templateImage(withName: .clockIcon))
        iv.tintColor = ColorPalette.color(withType: .primary)
        return iv
    }()
    private let underlineTime: UIView = {
        let view = UIView()
        view.backgroundColor = ColorPalette.color(withType: .primary)
        return view
    }()
    private let datePicker: UIDatePicker = {
        let dp = UIDatePicker()
        dp.datePickerMode = .dateAndTime
        dp.preferredDatePickerStyle = .inline
        dp.tintColor = ColorPalette.color(withType: .primary)
        dp.maximumDate = Date()  // prevent future dates
        return dp
    }()

    private let sectionHeaderDose: UILabel = {
        let lbl = UILabel()
        lbl.text = StringsProvider.string(forKey: .doseStepTwoDosesLabel)
        lbl.font = FontPalette.fontStyleData(forStyle: .paragraph).font
        lbl.textColor = ColorPalette.color(withType: .primary)
        return lbl
    }()

    private let doseRow: UIControl = {
        let ctrl = UIControl()
        ctrl.backgroundColor = .clear
        return ctrl
    }()
    private let doseTextField: UITextField = {
        let tf = UITextField()
        tf.keyboardType = .decimalPad
        tf.font = .preferredFont(forTextStyle: .body)
        tf.textColor = ColorPalette.color(withType: .primaryText)
        tf.placeholder = StringsProvider.string(forKey: .doseStepTwoUnitsLabel)
        tf.returnKeyType = .done
        return tf
    }()
    private let doseUnitsLabel: UILabel = {
        let lbl = UILabel()
        lbl.text = StringsProvider.string(forKey: .doseStepTwoUnitsLabel)
        lbl.font = FontPalette.fontStyleData(forStyle: .paragraph).font
        lbl.textColor = ColorPalette.color(withType: .primary)
        return lbl
    }()
    private let underlineDose: UIView = {
        let view = UIView()
        view.backgroundColor = ColorPalette.color(withType: .primary)
        return view
    }()

    private lazy var footerView: GenericButtonView = {
        let gv = GenericButtonView(withTextStyleCategory: .secondaryBackground(shadow: false))
        gv.setButtonText(StringsProvider.string(forKey: .doseStepTwoConfirmButton))
        gv.setButtonEnabled(enabled: false)
        gv.addTarget(target: self, action: #selector(confirmTapped))
        return gv
    }()

    // MARK: - State

    private var chosenDate: Date? { didSet { updateFooter() }}
    private var chosenDose: Double? { didSet { updateFooter() }}
    private func updateFooter() {
        footerView.setButtonEnabled(enabled: chosenDate != nil && chosenDose != nil)
    }
    
    private lazy var messages: [MessageInfo] = {
        let messages = self.storage.infoMessages?.messages(withLocation: .pageMyDoses)
        return messages ?? []
    }()

    // MARK: - Init

    init(displayTitle: String) {
        self.displayTitle = displayTitle
        self.navigator = Services.shared.navigator
        self.storage = Services.shared.storageServices
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ColorPalette.color(withType: .secondary)

        // Enable keyboard dismissal on drag
        scrollStackView.scrollView.keyboardDismissMode = .interactive

        // Add toolbar with Done button as input accessory
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        toolbar.frame = CGRect(x: 0,
                               y: 0,
                               width: view.bounds.width,
                               height: toolbar.frame.height)
        toolbar.autoresizingMask = [.flexibleWidth]
        let flex = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let done = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(donePressed))
        toolbar.items = [flex, done]
        doseTextField.inputAccessoryView = toolbar

        setupLayout()
        setupActions()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.secondary(hidden: false).style)
        addCustomBackButton()
    }

    // MARK: - Setup

    private func setupLayout() {
        // Info button
        let infoItem = UIBarButtonItem(
            image: ImagePalette.templateImage(withName: .infoMessage),
            style: .plain,
            target: self,
            action: #selector(infoPressed)
        )
        infoItem.tintColor = ColorPalette.color(withType: .primary)
        self.navigationItem.rightBarButtonItem = (self.messages.count < 1)
            ? nil
            : infoItem

        // Scroll + stack
        view.addSubview(scrollStackView)
        scrollStackView.autoPinEdgesToSuperviewSafeArea(with: .zero, excludingEdge: .bottom)

        // Title
        let paragraph = NSMutableParagraphStyle(); paragraph.alignment = .center
        let title = NSAttributedString(
            string: StringsProvider.string(forKey: .doseStepTwoTitle),
            attributes: [
                .font: UIFont.boldSystemFont(ofSize: FontPalette.fontStyleData(forStyle: .header2).font.pointSize),
                .foregroundColor: ColorPalette.color(withType: .primaryText),
                .paragraphStyle: paragraph
            ]
        )
        scrollStackView.stackView.addLabel(attributedString: title, numberOfLines: 1)
        scrollStackView.stackView.addBlankSpace(space: 36)

        // Subtitle
        let baseMsg = StringsProvider.string(forKey: .doseStepTwoMessage)
        let normalAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.preferredFont(forTextStyle: .body),
            .foregroundColor: ColorPalette.color(withType: .primaryText),
            .paragraphStyle: paragraph
        ]
        let boldAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize),
            .foregroundColor: ColorPalette.color(withType: .primaryText),
            .paragraphStyle: paragraph
        ]
        let subtitle = NSMutableAttributedString(string: baseMsg, attributes: normalAttrs)
        subtitle.append(NSAttributedString(string: " " + displayTitle, attributes: boldAttrs))
        subtitleLabel.attributedText = subtitle
        scrollStackView.stackView.addArrangedSubview(subtitleLabel)
        scrollStackView.stackView.addBlankSpace(space: 70)

        // Date Section
        scrollStackView.stackView.addArrangedSubview(sectionHeaderTime)
        scrollStackView.stackView.addBlankSpace(space: 8)
        scrollStackView.stackView.addArrangedSubview(dateRow)
        dateRow.autoSetDimension(.height, toSize: 44)
        dateRow.addSubview(dateValueLabel); dateRow.addSubview(dateIcon); dateRow.addSubview(underlineTime)
        dateValueLabel.autoAlignAxis(toSuperviewAxis: .horizontal)
        dateValueLabel.autoPinEdge(.leading, to: .leading, of: dateRow)
        dateIcon.autoAlignAxis(.horizontal, toSameAxisOf: dateValueLabel)
        dateIcon.autoPinEdge(.trailing, to: .trailing, of: dateRow)
        dateIcon.autoSetDimensions(to: CGSize(width: 24, height: 24))
        underlineTime.autoPinEdge(.bottom, to: .bottom, of: dateRow)
        underlineTime.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .top)
        underlineTime.autoSetDimension(.height, toSize: 1)
        scrollStackView.stackView.addArrangedSubview(datePicker)
        datePicker.isHidden = true
        scrollStackView.stackView.addBlankSpace(space: 36)

        // Dose Section
        scrollStackView.stackView.addArrangedSubview(sectionHeaderDose)
        scrollStackView.stackView.addBlankSpace(space: 8)
        scrollStackView.stackView.addArrangedSubview(doseRow)
        doseRow.autoSetDimension(.height, toSize: 44)
        doseRow.addSubview(doseTextField); doseRow.addSubview(doseUnitsLabel); doseRow.addSubview(underlineDose)
        doseTextField.autoAlignAxis(toSuperviewAxis: .horizontal)
        doseTextField.autoPinEdge(.leading, to: .leading, of: doseRow)
        doseUnitsLabel.autoAlignAxis(.horizontal, toSameAxisOf: doseTextField)
        doseUnitsLabel.autoPinEdge(.trailing, to: .trailing, of: doseRow)
        underlineDose.autoPinEdge(.bottom, to: .bottom, of: doseRow)
        underlineDose.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .top)
        underlineDose.autoSetDimension(.height, toSize: 1)
        scrollStackView.stackView.addBlankSpace(space: 36)

        // Footer
        view.addSubview(footerView)
        footerView.autoPinEdgesToSuperviewSafeArea(with: .zero, excludingEdge: .top)
        scrollStackView.scrollView.autoPinEdge(.bottom, to: .top, of: footerView)
    }

    private func setupActions() {
        dateRow.addTarget(self, action: #selector(togglePicker), for: .touchUpInside)
        datePicker.addTarget(self, action: #selector(pickerChanged(_:)), for: .valueChanged)
        doseTextField.delegate = self
        doseTextField.addTarget(self, action: #selector(doseChanged(_:)), for: .editingChanged)
        doseRow.addTarget(self, action: #selector(doseRowTapped), for: .touchUpInside)
    }

    // MARK: - Actions

    @objc private func togglePicker() {
        doseTextField.resignFirstResponder()
        datePicker.isHidden.toggle()
    }

    @objc private func pickerChanged(_ dp: UIDatePicker) {
        chosenDate = dp.date
        let fmt = DateFormatter()
        fmt.dateStyle = .short
        fmt.timeStyle = .short
        dateValueLabel.text = fmt.string(from: dp.date)
    }

    @objc private func doseChanged(_ tf: UITextField) {
        if let txt = tf.text, let val = Double(txt) {
            chosenDose = val
        } else {
            chosenDose = nil
        }
    }

    @objc private func doseRowTapped() {
        datePicker.isHidden = true
        doseTextField.becomeFirstResponder()
    }

    @objc private func confirmTapped() {
        guard let date = chosenDate, let amount = chosenDose else { return }
        delegate?.doseDateTimeViewController(self, didSelect: date, amount: amount)
    }

    @objc private func infoPressed() {
        navigator.openMessagePage(withLocation: .pageMyDoses,
                                  presenter: self)
    }

    // MARK: - UITextFieldDelegate

    @objc func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    // Dismiss keyboard when tapping outside
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        view.endEditing(true)
    }

    // MARK: - Done Button Action

    @objc private func donePressed() {
        doseTextField.resignFirstResponder()
    }
}
