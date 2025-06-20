//
//  DoseTypeViewController.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 19/05/25.
//

import UIKit
import PureLayout

/// Protocol to notify delegate of selected dose type or cancellation
protocol DoseTypeViewControllerDelegate: AnyObject {
    /// Called when user selects a dose type
    func doseTypeViewController(_ vc: DoseTypeViewController,
                                didSelect type: DoseType)
    /// Called when user taps back/cancel
    func doseTypeViewControllerDidCancel(_ vc: DoseTypeViewController)
}

/// View controller to let user choose between pump bolus or insulin injection
class DoseTypeViewController: UIViewController {
    
    private let variant: FlowVariant
    
    private lazy var messages: [MessageInfo] = {
        if let storage = Services.shared.storageServices {
            let location: MessageInfoParameter = (variant == .embeddedInNoticed) ? .pageWeHaveNoticed : .pageMyDoses
            let messages = storage.infoMessages?.messages(withLocation: location)
            return messages ?? []
        }
        return []
    }()

    // MARK: - Public API
    weak var delegate: DoseTypeViewControllerDelegate?
    var alert: Alert?
    
    private lazy var infoButton: UIBarButtonItem = {
        let item = UIBarButtonItem(
            image: ImagePalette.templateImage(withName: .infoMessage),
            style: .plain,
            target: self,
            action: #selector(infoButtonPressed)
        )
        item.tintColor = ColorPalette.color(withType: .primary)
        return item
    }()
    
    // MARK: - Subviews
    
    private let scrollStack = ScrollStackView(
        axis: .vertical,
        horizontalInset: Constants.Style.DefaultHorizontalMargins
    )
    
    private lazy var pumpButton: OptionButton = makeOptionButton(type: .pumpBolus)
    private lazy var injectionButton: OptionButton = makeOptionButton(type: .insulinInjection)
    
    private lazy var closeButton: UIBarButtonItem = {
        let item = UIBarButtonItem(
                image: ImagePalette.templateImage(withName: .closeButton),
                style: .plain,
                target: self,
                action: #selector(closeButtonPressed)
            )
            // Tint color
            item.tintColor = ColorPalette.color(withType: .primaryText)
            return item
    }()
    
    private lazy var footerView: GenericButtonView = {
        let buttonText = (variant == .standalone)
        ? StringsProvider.string(forKey: .doseNextButton)
        : StringsProvider.string(forKey: .noticedStepNextButton)
        let buttonView = GenericButtonView(withTextStyleCategory: .secondaryBackground(shadow: false))
        buttonView.setButtonText(buttonText)
        buttonView.setButtonEnabled(enabled: false)
        buttonView.addTarget(target: self, action: #selector(nextTapped))
        return buttonView
    }()
    
    // MARK: - State
    
    private var selectedType: DoseType? {
        didSet {
            // Enable Next button only after a selection
            footerView.setButtonEnabled(enabled: selectedType != nil)
        }
    }
    
    // MARK: - Init
    
    init(variant: FlowVariant) {
        self.variant = variant
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ColorPalette.color(withType: .secondary)
        setupNavigationBar()
        setupLayout()
        setupActions()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if variant == .embeddedInNoticed {
            addCustomBackButton()
            navigationItem.rightBarButtonItem = self.messages.count > 0 ? self.infoButton : nil
        }
    }
    
    // MARK: - Setup
    
    private func setupNavigationBar() {
        navigationController?.navigationBar.apply(
            style: NavigationBarStyleCategory.secondary(hidden: false).style)
    }
    
    private func setupLayout() {
        
        if variant == .standalone {
            self.navigationItem.leftBarButtonItem = self.closeButton
        }

        // Add scroll + stack
        view.addSubview(scrollStack)
        scrollStack.autoPinEdgesToSuperviewSafeArea(with: .zero, excludingEdge: .bottom)
        
        // Header: "Add a dose"
        let title = (variant == .standalone)
        ? StringsProvider.string(forKey: .doseStepOneTitle)
        : StringsProvider.string(forKey: .noticedStepTwoTitle)
        
        let header = NSAttributedString(
            string: title,
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
        scrollStack.stackView.addLabel(attributedString: header, numberOfLines: 1)
        scrollStack.stackView.addBlankSpace(space: 36)
        
        if let alert = alert?.body {
            scrollStack.stackView.addLabel(
                withText: alert,
                fontStyle: .paragraph,
                color: ColorPalette.color(withType: .primaryText)
            )
            scrollStack.stackView.addBlankSpace(space: 40)
        }
        
        // Subtitle: "What type did you use?"
        let message = (variant == .standalone)
        ? StringsProvider.string(forKey: .doseStepOneMessage)
        : StringsProvider.string(forKey: .noticedStepTwoMessage)
        
        scrollStack.stackView.addLabel(
            withText: message,
            fontStyle: .paragraph,
            color: ColorPalette.color(withType: .primaryText)
        )
        scrollStack.stackView.addBlankSpace(space: 44)
        
        // Dose type options
        [pumpButton, injectionButton].forEach { btn in
            scrollStack.stackView.addArrangedSubview(btn)
            scrollStack.stackView.addBlankSpace(space: 16)
            btn.autoSetDimension(.height, toSize: 60)
        }
        
        // Footer
        view.addSubview(footerView)
        footerView.autoPinEdgesToSuperviewSafeArea(with: .zero, excludingEdge: .top)
        scrollStack.scrollView.autoPinEdge(.bottom, to: .top, of: footerView)
    }
    
    private func makeOptionButton(type: DoseType) -> OptionButton {
        // Create an OptionButton with left-aligned text
        let btn = OptionButton()
        btn.layoutStyle = .textLeft(padding: 16)
        btn.setTitle(type.displayText(usingVariant: self.variant), for: .normal)
        return btn
    }
    
    private func setupActions() {
        // Wire up button taps
        pumpButton.addTarget(self, action: #selector(optionTapped(_:)), for: .touchUpInside)
        injectionButton.addTarget(self, action: #selector(optionTapped(_:)), for: .touchUpInside)
    }
    
    // MARK: - Actions
    
    @objc private func optionTapped(_ sender: OptionButton) {
        // Deselect both, then select tapped
        pumpButton.isSelected = (sender == pumpButton)
        injectionButton.isSelected = (sender == injectionButton)
        
        // Store the selected enum value
        if sender == pumpButton {
            selectedType = .pumpBolus
        } else {
            selectedType = .insulinInjection
        }
    }
    
    @objc private func nextTapped() {
        guard let type = selectedType else { return }
        delegate?.doseTypeViewController(self, didSelect: type)
    }
    
    // MARK: Actions
    @objc private func closeButtonPressed() {
        self.delegate?.doseTypeViewControllerDidCancel(self)
    }
    
    @objc private func infoButtonPressed() {
        let navigator = Services.shared.navigator
        let location: MessageInfoParameter = (variant == .embeddedInNoticed) ? .pageWeHaveNoticed : .pageMyDoses
        navigator?.openMessagePage(withLocation: location, presenter: self)
    }
}
