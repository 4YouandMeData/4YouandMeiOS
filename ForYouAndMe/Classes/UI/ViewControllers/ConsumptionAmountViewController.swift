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
}

class ConsumptionAmountViewController: UIViewController {

    // MARK: – Public API

    /// The type we ate (snack/meal)
    var selectedType: EatenTypeViewController.EntryType!
    private let storage: CacheService
    private let navigator: AppNavigator
    weak var delegate: ConsumptionAmountViewControllerDelegate?

    // MARK: – Subviews

    private let scrollStack = ScrollStackView(
        axis: .vertical,
        horizontalInset: Constants.Style.DefaultHorizontalMargins
    )

    private lazy var moreButton: OptionButton = makeOption(
        text: StringsProvider.string(forKey: .diaryNoteEatenStepFourthFirstButton),
        iconName: .plusIcon,
        value: .moreThanUsual
    )
    private lazy var sameButton: OptionButton = makeOption(
        text: StringsProvider.string(forKey: .diaryNoteEatenStepFourthSecondButton),
        iconName: .equalsIcon,
        value: .asUsual
    )
    private lazy var lessButton: OptionButton = makeOption(
        text: StringsProvider.string(forKey: .diaryNoteEatenStepFourthThirdButton),
        iconName: .minusIcon,
        value: .lessThanUsual
    )

    private lazy var footerView: GenericButtonView = {
        let buttonView = GenericButtonView(withTextStyleCategory: .secondaryBackground(shadow: false))
        buttonView.setButtonText(StringsProvider.string(forKey: .diaryNoteEatenNextButton))
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
        let messages = self.storage.infoMessages?.messages(withLocation: .pageIHaveEeaten)
        return messages ?? []
    }()

    // MARK: – Lifecycle
    
    init() {
        self.navigator = Services.shared.navigator
        self.storage = Services.shared.storageServices
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
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let boldTitle = NSAttributedString(
            string: StringsProvider.string(forKey: .diaryNoteEatenStepFourthTitle),
            attributes: [
                .font: UIFont.boldSystemFont(ofSize: FontPalette.fontStyleData(forStyle: .header2).font.pointSize),
                .foregroundColor: ColorPalette.color(withType: .primaryText),
                .paragraphStyle: paragraph
            ]
        )
        scrollStack.stackView.addLabel(attributedString: boldTitle, numberOfLines: 1)
        scrollStack.stackView.addBlankSpace(space: 36)

        // Subtitle
        let base = StringsProvider.string(forKey: .diaryNoteEatenStepFourthMessage)
        let boldPart = " " + selectedType.rawValue.lowercased()
        let end = "..."
        let att = NSMutableAttributedString(string: base, attributes: [
            .font: FontPalette.fontStyleData(forStyle: .paragraph).font,
            .foregroundColor: ColorPalette.color(withType: .primaryText),
            .paragraphStyle: paragraph
        ])
        att.append(NSAttributedString(string: boldPart, attributes: [
            .font: UIFont.boldSystemFont(ofSize: FontPalette.fontStyleData(forStyle: .paragraph).font.pointSize),
            .foregroundColor: ColorPalette.color(withType: .primaryText),
            .paragraphStyle: paragraph
        ]))
        att.append(NSAttributedString(string: end, attributes: [
            .font: FontPalette.fontStyleData(forStyle: .paragraph).font,
            .foregroundColor: ColorPalette.color(withType: .primaryText),
            .paragraphStyle: paragraph
        ]))
        scrollStack.stackView.addLabel(attributedString: att)
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
        self.navigator.openMessagePage(withLocation: .pageIHaveEeaten, presenter: self)
    }
}
