//
//  CaloriesInputViewController.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 16/05/25.
//

import UIKit
import PureLayout

protocol CaloriesInputViewControllerDelegate: AnyObject {
    /// Called when user taps "Next" with calories value
    func caloriesInputViewController(_ vc: CaloriesInputViewController,
                                    didEnterCalories value: Int)
    /// Called when user dismisses this screen (e.g. via back)
    func caloriesInputViewControllerDidCancel(_ vc: CaloriesInputViewController)
}

/// View controller to input calories amount
class CaloriesInputViewController: UIViewController, UITextFieldDelegate {

    // MARK: - Public API
    var alert: Alert?
    
    /// The food type (snack/meal) to display in message
    var selectedType: FoodEntryType!
    weak var delegate: CaloriesInputViewControllerDelegate?
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

    private let caloriesRow: UIControl = {
        let ctrl = UIControl()
        ctrl.backgroundColor = .clear
        return ctrl
    }()
    
    private let caloriesTextField: UITextField = {
        let tf = UITextField()
        tf.keyboardType = .numberPad
        tf.font = .preferredFont(forTextStyle: .body)
        tf.textColor = ColorPalette.color(withType: .primaryText)
        tf.text = "0"
        return tf
    }()
    
    private let caloriesUnitsLabel: UILabel = {
        let lbl = UILabel()
        lbl.font = FontPalette.fontStyleData(forStyle: .paragraph).font
        lbl.textColor = ColorPalette.color(withType: .primary)
        return lbl
    }()
    
    private let underlineCalories: UIView = {
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

    private var chosenCalories: Int? { 
        didSet { 
            updateFooter()
        }
    }
    
    private func updateFooter() {
        let hasValidValue = chosenCalories != nil && chosenCalories! > 0
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
        chosenCalories = 0
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
        ? StringsProvider.string(forKey: .diaryNoteEatenStepCaloriesAmountTitle)
        : StringsProvider.string(forKey: .noticedStepCaloriesAmountTitle)
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
        ? StringsProvider.string(forKey: .diaryNoteEatenStepCaloriesAmountMessage)
            .replacingPlaceholders(with: [replacementString])
        : StringsProvider.string(forKey: .noticedStepCaloriesAmountMessage)
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

        // Calories Section
        caloriesUnitsLabel.text = variant.isStandaloneLike
        ? StringsProvider.string(forKey: .diaryNoteEatenStepCaloriesAmountUnitsLabel)
        : StringsProvider.string(forKey: .noticedStepCaloriesAmountUnitsLabel)
        
        scrollStackView.stackView.addArrangedSubview(caloriesRow)
        caloriesRow.autoSetDimension(.height, toSize: 44)
        
        caloriesRow.addSubview(caloriesTextField)
        caloriesRow.addSubview(caloriesUnitsLabel)
        caloriesRow.addSubview(underlineCalories)
        
        caloriesTextField.autoAlignAxis(toSuperviewAxis: .horizontal)
        caloriesTextField.autoPinEdge(.leading, to: .leading, of: caloriesRow)
        caloriesUnitsLabel.autoAlignAxis(.horizontal, toSameAxisOf: caloriesTextField)
        caloriesUnitsLabel.autoPinEdge(.trailing, to: .trailing, of: caloriesRow)
        underlineCalories.autoPinEdge(.bottom, to: .bottom, of: caloriesRow)
        underlineCalories.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .top)
        underlineCalories.autoSetDimension(.height, toSize: 1)
        scrollStackView.stackView.addBlankSpace(space: 36)

        // Footer
        view.addSubview(footerView)
        footerView.autoPinEdgesToSuperviewSafeArea(with: .zero, excludingEdge: .top)
        scrollStackView.scrollView.autoPinEdge(.bottom, to: .top, of: footerView)
    }

    private func setupActions() {
        caloriesTextField.delegate = self
        caloriesTextField.addTarget(self, action: #selector(caloriesChanged(_:)), for: .editingChanged)
        caloriesRow.addTarget(self, action: #selector(caloriesRowTapped), for: .touchUpInside)
        
        // Add tap gesture to dismiss keyboard when tapping outside
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        scrollStackView.scrollView.addGestureRecognizer(tapGesture)
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    // MARK: - Actions

    @objc private func caloriesChanged(_ tf: UITextField) {
        if let txt = tf.text, let val = Int(txt) {
            chosenCalories = val
        } else {
            chosenCalories = nil
        }
    }

    @objc private func caloriesRowTapped() {
        caloriesTextField.becomeFirstResponder()
    }

    @objc private func nextTapped() {
        guard let calories = chosenCalories, calories > 0 else { return }
        delegate?.caloriesInputViewController(self, didEnterCalories: calories)
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

