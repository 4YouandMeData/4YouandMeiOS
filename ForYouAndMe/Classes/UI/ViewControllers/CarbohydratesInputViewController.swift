//
//  CarbohydratesInputViewController.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 16/05/25.
//

import UIKit
import PureLayout

protocol CarbohydratesInputViewControllerDelegate: AnyObject {
    /// Called when user taps "Next" with carbohydrates value
    func carbohydratesInputViewController(_ vc: CarbohydratesInputViewController,
                                    didEnterCarbohydrates value: Int)
    /// Called when user dismisses this screen (e.g. via back)
    func carbohydratesInputViewControllerDidCancel(_ vc: CarbohydratesInputViewController)
}

/// View controller to input carbohydrates amount
class CarbohydratesInputViewController: UIViewController, UITextFieldDelegate {

    // MARK: - Public API
    var alert: Alert?
    
    /// The food type (snack/meal) to display in message
    var selectedType: FoodEntryType!
    weak var delegate: CarbohydratesInputViewControllerDelegate?
    private let storage: CacheService
    private let navigator: AppNavigator
    private let variant: FlowVariant

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

    private let carbohydratesRow: UIControl = {
        let ctrl = UIControl()
        ctrl.backgroundColor = .clear
        return ctrl
    }()
    
    private let carbohydratesTextField: UITextField = {
        let tf = UITextField()
        tf.keyboardType = .numberPad
        tf.font = .preferredFont(forTextStyle: .body)
        tf.textColor = ColorPalette.color(withType: .primaryText)
        tf.text = "0"
        return tf
    }()
    
    private let carbohydratesUnitsLabel: UILabel = {
        let lbl = UILabel()
        lbl.font = FontPalette.fontStyleData(forStyle: .paragraph).font
        lbl.textColor = ColorPalette.color(withType: .primary)
        return lbl
    }()
    
    private let underlineCarbohydrates: UIView = {
        let view = UIView()
        view.backgroundColor = ColorPalette.color(withType: .primary)
        return view
    }()

    private lazy var footerView: GenericButtonView = {
        let key = variant.isStandaloneLike
        ? StringsProvider.string(forKey: .diaryNoteEatenNextButton)
        : StringsProvider.string(forKey: .noticedStepNextButton)
        let gv = GenericButtonView(withTextStyleCategory: .secondaryBackground(shadow: false))
        gv.setButtonText(key)
        gv.setButtonEnabled(enabled: false)
        gv.addTarget(target: self, action: #selector(nextTapped))
        return gv
    }()

    // MARK: - State

    private var chosenCarbohydrates: Int? { 
        didSet { 
            updateFooter()
        }
    }
    
    private func updateFooter() {
        let hasValidValue = chosenCarbohydrates != nil && chosenCarbohydrates! > 0
        footerView.setButtonEnabled(enabled: hasValidValue)
    }
    
    private lazy var messages: [MessageInfo] = {
        let location: MessageInfoParameter = variant.isStandaloneLike ? .pageIHaveEeaten : .pageWeHaveNoticed
        let messages = self.storage.infoMessages?.messages(withLocation: location)
        return messages ?? []
    }()

    // MARK: - Lifecycle

    init(variant: FlowVariant) {
        self.navigator = Services.shared.navigator
        self.storage = Services.shared.storageServices
        self.variant = variant
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ColorPalette.color(withType: .secondary)
        setupNavigationBar()
        setupLayout()
        setupActions()
        
        // Initialize with default value
        chosenCarbohydrates = 0
    }

    // MARK: - Setup

    private func setupNavigationBar() {
        navigationController?.navigationBar.apply(
            style: NavigationBarStyleCategory.secondary(hidden: false).style
        )
        addCustomBackButton()
        
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
    }

    private func setupLayout() {
        // Scroll + stack
        view.addSubview(scrollStackView)
        scrollStackView.autoPinEdgesToSuperviewSafeArea(with: .zero, excludingEdge: .bottom)

        // Title
        let titleKey = variant.isStandaloneLike
        ? StringsProvider.string(forKey: .diaryNoteEatenStepCarbohydratesAmountTitle)
        : StringsProvider.string(forKey: .noticedStepCarbohydratesAmountTitle)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        
        let title = NSAttributedString(
            string: titleKey,
            attributes: [
                .font: UIFont.boldSystemFont(ofSize: FontPalette.fontStyleData(forStyle: .header2).font.pointSize),
                .foregroundColor: ColorPalette.color(withType: .primaryText),
                .paragraphStyle: paragraph
            ]
        )
        scrollStackView.stackView.addLabel(attributedString: title, numberOfLines: 1)
        scrollStackView.stackView.addBlankSpace(space: 36)
        
        if let alert = alert?.body {
            scrollStackView.stackView.addLabel(
                withText: alert,
                fontStyle: .paragraph,
                color: ColorPalette.color(withType: .primaryText)
            )
            scrollStackView.stackView.addBlankSpace(space: 40)
        }
        
        let replacementString = selectedType.displayTextUsingVariant(variant: self.variant).lowercased()

        // Subtitle
        let messageKey = variant.isStandaloneLike
        ? StringsProvider.string(forKey: .diaryNoteEatenStepCarbohydratesAmountMessage)
            .replacingPlaceholders(with: [replacementString])
        : StringsProvider.string(forKey: .noticedStepCarbohydratesAmountMessage)
            .replacingPlaceholders(with: [replacementString])
        
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
        if let boldRange = messageKey.range(of: replacementString) {
            let nsRange = NSRange(boldRange, in: messageKey)
            attributed.addAttributes(attrsBold, range: nsRange)
        }
        
        func applyBold(to substring: String) {
            let fullText = attributed.string as NSString
            let range = fullText.range(of: substring, options: .caseInsensitive)
            guard range.location != NSNotFound else { return }
            attributed.addAttributes(attrsBold, range: range)
        }
        
        let typeKey = selectedType.rawValue
        applyBold(to: typeKey)
        
        subtitleLabel.attributedText = attributed
        scrollStackView.stackView.addArrangedSubview(subtitleLabel)
        scrollStackView.stackView.addBlankSpace(space: 70)

        // Carbohydrates Section
        carbohydratesUnitsLabel.text = variant.isStandaloneLike
        ? StringsProvider.string(forKey: .diaryNoteEatenStepCarbohydratesAmountUnitsLabel)
        : StringsProvider.string(forKey: .noticedStepCarbohydratesAmountUnitsLabel)
        
        scrollStackView.stackView.addArrangedSubview(carbohydratesRow)
        carbohydratesRow.autoSetDimension(.height, toSize: 44)
        
        carbohydratesRow.addSubview(carbohydratesTextField)
        carbohydratesRow.addSubview(carbohydratesUnitsLabel)
        carbohydratesRow.addSubview(underlineCarbohydrates)
        
        carbohydratesTextField.autoAlignAxis(toSuperviewAxis: .horizontal)
        carbohydratesTextField.autoPinEdge(.leading, to: .leading, of: carbohydratesRow)
        carbohydratesUnitsLabel.autoAlignAxis(.horizontal, toSameAxisOf: carbohydratesTextField)
        carbohydratesUnitsLabel.autoPinEdge(.trailing, to: .trailing, of: carbohydratesRow)
        underlineCarbohydrates.autoPinEdge(.bottom, to: .bottom, of: carbohydratesRow)
        underlineCarbohydrates.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .top)
        underlineCarbohydrates.autoSetDimension(.height, toSize: 1)
        scrollStackView.stackView.addBlankSpace(space: 36)

        // Footer
        view.addSubview(footerView)
        footerView.autoPinEdgesToSuperviewSafeArea(with: .zero, excludingEdge: .top)
        scrollStackView.scrollView.autoPinEdge(.bottom, to: .top, of: footerView)
    }

    private func setupActions() {
        carbohydratesTextField.delegate = self
        carbohydratesTextField.addTarget(self, action: #selector(carbohydratesChanged(_:)), for: .editingChanged)
        carbohydratesRow.addTarget(self, action: #selector(carbohydratesRowTapped), for: .touchUpInside)
        
        // Add tap gesture to dismiss keyboard when tapping outside
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        scrollStackView.scrollView.addGestureRecognizer(tapGesture)
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    // MARK: - Actions

    @objc private func carbohydratesChanged(_ tf: UITextField) {
        if let txt = tf.text, let val = Int(txt) {
            chosenCarbohydrates = val
        } else {
            chosenCarbohydrates = nil
        }
    }

    @objc private func carbohydratesRowTapped() {
        carbohydratesTextField.becomeFirstResponder()
    }

    @objc private func nextTapped() {
        guard let carbohydrates = chosenCarbohydrates, carbohydrates > 0 else { return }
        delegate?.carbohydratesInputViewController(self, didEnterCarbohydrates: carbohydrates)
    }

    @objc private func infoPressed() {
        let location: MessageInfoParameter = variant.isStandaloneLike ? .pageIHaveEeaten : .pageWeHaveNoticed
        navigator.openMessagePage(withLocation: location, presenter: self)
    }

    // MARK: - UITextFieldDelegate

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

