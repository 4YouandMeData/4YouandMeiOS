//
//  ConsumptionAmountViewController.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 16/05/25.
//

import UIKit
import PureLayout

protocol ConsumptionAmountViewControllerDelegate: AnyObject {
    /// Called when user selects an amount
    func consumptionAmountViewController(_ vc: ConsumptionAmountViewController,
                                         didSelect amount: String)
    /// Called when user taps back/cancel
    func consumptionAmountViewControllerDidCancel(_ vc: ConsumptionAmountViewController)
}

/// Represents the three possible consumption quantities for food diary
enum ConsumptionQuantity: String {
    case moreThanUsual   = "more_than_usual"
    case asUsual         = "as_usual"
    case lessThanUsual   = "less_than_usual"
    
    func displayTextUsingVariant(variant: FlowVariant) -> String {
        switch variant {
        case .embeddedInNoticed:
            switch self {
            case .moreThanUsual: return StringsProvider.string(forKey: .noticedStepEightFirstButton)
            case .asUsual:  return StringsProvider.string(forKey: .noticedStepEightSecondButton)
            case .lessThanUsual: return StringsProvider.string(forKey: .noticedStepEightThirdButton)
            }
        case .standalone:
            switch self {
            case .moreThanUsual: return StringsProvider.string(forKey: .diaryNoteEatenStepFourthFirstButton)
            case .asUsual:  return StringsProvider.string(forKey: .diaryNoteEatenStepFourthSecondButton)
            case .lessThanUsual: return StringsProvider.string(forKey: .diaryNoteEatenStepFourthThirdButton)
            }
        }
        
    }
}

class ConsumptionAmountViewController: UIViewController {

    // MARK: – Public API

    /// The type we ate (snack/meal)
    var selectedType: FoodEntryType!
    var alert: Alert?
    
    private let storage: CacheService
    private let navigator: AppNavigator
    weak var delegate: ConsumptionAmountViewControllerDelegate?
    private let variant: FlowVariant

    // MARK: – Subviews

    private let scrollStack = ScrollStackView(
        axis: .vertical,
        horizontalInset: Constants.Style.DefaultHorizontalMargins
    )

    private lazy var moreButton: OptionButton = makeOption(
        text: (variant == .standalone)
        ? StringsProvider.string(forKey: .diaryNoteEatenStepFourthFirstButton)
        : StringsProvider.string(forKey: .noticedStepEightFirstButton),
        iconName: .plusIcon,
        value: .moreThanUsual
    )
    private lazy var sameButton: OptionButton = makeOption(
        text: (variant == .standalone)
        ? StringsProvider.string(forKey: .diaryNoteEatenStepFourthSecondButton)
        : StringsProvider.string(forKey: .noticedStepEightSecondButton),
        iconName: .equalsIcon,
        value: .asUsual
    )
    private lazy var lessButton: OptionButton = makeOption(
        text: (variant == .standalone)
        ? StringsProvider.string(forKey: .diaryNoteEatenStepFourthThirdButton)
        : StringsProvider.string(forKey: .noticedStepEightThirdButton),
        iconName: .minusIcon,
        value: .lessThanUsual
    )

    private lazy var footerView: GenericButtonView = {
        let buttonView = GenericButtonView(withTextStyleCategory: .secondaryBackground(shadow: false))
        let buttonKey = (variant == .standalone)
        ? StringsProvider.string(forKey: .diaryNoteEatenNextButton)
        : StringsProvider.string(forKey: .noticedStepNextButton)
        buttonView.setButtonText(buttonKey)
        buttonView.setButtonEnabled(enabled: false)
        buttonView.addTarget(target: self, action: #selector(self.nextTapped))
        return buttonView
    }()

    // MARK: – State

    /// The selected consumption quantity enum
    private var selectedQuantity: ConsumptionQuantity? {
        didSet {
            footerView.setButtonEnabled(enabled: selectedQuantity != nil)
        }
    }
    
    private lazy var messages: [MessageInfo] = {
        let location: MessageInfoParameter = (variant == .embeddedInNoticed) ? .pageWeHaveNoticed : .pageIHaveEeaten
        let messages = self.storage.infoMessages?.messages(withLocation: location)
        return messages ?? []
    }()

    // MARK: – Lifecycle
    
    init(variant: FlowVariant) {
        self.navigator = Services.shared.navigator
        self.storage = Services.shared.storageServices
        self.variant = variant
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        print("DiaryNoteViewController - deinit")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ColorPalette.color(withType: .secondary)
        setupNavigationBar()
        setupLayout()
        setupActions()
    }

    // MARK: – Setup

    private func setupNavigationBar() {
        navigationController?.navigationBar.apply(
            style: NavigationBarStyleCategory.secondary(hidden: false).style
        )
        addCustomBackButton()
    }

    private func setupLayout() {
        
        // Create a bar button item with your info image
        let comingSoonItem = UIBarButtonItem(
            image: ImagePalette.templateImage(withName: .infoMessage),
            style: .plain,
            target: self,
            action: #selector(infoButtonPressed)
        )
        comingSoonItem.tintColor = ColorPalette.color(withType: .primary)
        self.navigationItem.rightBarButtonItem = (self.messages.count < 1)
            ? nil
            : comingSoonItem
        
        view.addSubview(scrollStack)
        scrollStack.autoPinEdgesToSuperviewSafeArea(with: .zero, excludingEdge: .bottom)

        // Title
        let buttonKey = (variant == .standalone)
        ? StringsProvider.string(forKey: .diaryNoteEatenStepFourthTitle)
        : StringsProvider.string(forKey: .noticedStepEightTitle)
        
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let boldTitle = NSAttributedString(
            string: buttonKey,
            attributes: [
                .font: UIFont.boldSystemFont(ofSize: FontPalette.fontStyleData(forStyle: .header2).font.pointSize),
                .foregroundColor: ColorPalette.color(withType: .primaryText),
                .paragraphStyle: paragraph
            ]
        )
        scrollStack.stackView.addLabel(attributedString: boldTitle, numberOfLines: 1)
        scrollStack.stackView.addBlankSpace(space: 36)

        let replacementString = selectedType.displayTextUsingVariant(variant: self.variant).lowercased()

        // Subtitle
        let messageKey = (variant == .standalone)
        ? StringsProvider.string(forKey: .diaryNoteEatenStepFourthMessage)
            .replacingPlaceholders(with: [replacementString])
        : StringsProvider.string(forKey: .noticedStepEightMessage)
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
        
        if let alert = alert?.body {
            scrollStack.stackView.addLabel(
                withText: alert,
                fontStyle: .paragraph,
                color: ColorPalette.color(withType: .primaryText)
            )
            scrollStack.stackView.addBlankSpace(space: 40)
        }
        
        scrollStack.stackView.addLabel(attributedString: attributed)
        scrollStack.stackView.addBlankSpace(space: 70)

        // Options list
        [moreButton, sameButton, lessButton].forEach { button in
            scrollStack.stackView.addArrangedSubview(button)
            scrollStack.stackView.addBlankSpace(space: 16)
            button.autoSetDimension(.height, toSize: 60)
        }

        // Footer ‘Next’
        view.addSubview(footerView)
        footerView.autoPinEdgesToSuperviewSafeArea(with: .zero, excludingEdge: .top)
        scrollStack.scrollView.autoPinEdge(.bottom, to: .top, of: footerView)
    }

    private func makeOption(text: String, iconName: TemplateImageName, value: ConsumptionQuantity) -> OptionButton {
        let btn = OptionButton()
        btn.layoutStyle = .horizontal(spacing: 16, horizontalAlignment: .leading)
        let img = ImagePalette.templateImage(withName: iconName)?.withRenderingMode(.alwaysTemplate)
        btn.setImage(img, for: .normal)
        btn.tintColor = ColorPalette.color(withType: .primary)
        btn.setTitle(text, for: .normal)
        btn.titleLabel?.font = FontPalette.fontStyleData(forStyle: .paragraph).font
        // Associate the enum value
        btn.accessibilityValue = value.rawValue
        return btn
    }

    private func setupActions() {
        [moreButton, sameButton, lessButton].forEach {
            $0.addTarget(self, action: #selector(optionTapped(_:)), for: .touchUpInside)
        }
    }

    // MARK: – Actions

    @objc private func optionTapped(_ sender: OptionButton) {
        // Deselect all and select tapped
        [moreButton, sameButton, lessButton].forEach { $0.isSelected = ($0 == sender) }
        // Retrieve the associated enum rawValue
        if let raw = sender.accessibilityValue,
           let qty = ConsumptionQuantity(rawValue: raw) {
            selectedQuantity = qty
        }
    }

    @objc private func nextTapped() {
        guard let qty = selectedQuantity else { return }
        delegate?.consumptionAmountViewController(self,
            didSelect: qty.rawValue)
    }
    
    @objc private func infoButtonPressed() {
        let location: MessageInfoParameter = (variant == .embeddedInNoticed) ? .pageWeHaveNoticed : .pageIHaveEeaten
        self.navigator.openMessagePage(withLocation: location, presenter: self)
    }
}
