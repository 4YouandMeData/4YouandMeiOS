//
//  StressLevelViewController.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 06/06/25.
//

import UIKit
import PureLayout

/// Delegate protocol to notify about the selected stress level or cancellation
protocol StressLevelViewControllerDelegate: AnyObject {
    /// Called when the user selects a stress level and taps “Confirm”
    func stressLevelViewController(_ vc: StressLevelViewController,
                                   didSelect level: StressLevel)
    /// Called when the user taps the close (“X”) button
    func stressLevelViewControllerDidCancel(_ vc: StressLevelViewController)
}

/// A view controller that asks “Just before the time listed above, how would you rate your stress level?”
/// with five options: Not stressed at all, A little stressed, Somewhat stressed, Stressed, Very stressed.
class StressLevelViewController: UIViewController {
    
    // MARK: – Public API
    
    weak var delegate: StressLevelViewControllerDelegate?
    
    // MARK: – Flow Variant
    
    /// Indicates whether this controller is running in “standalone” vs “noticed” mode.
    private let variant: FlowVariant
    
    // MARK: – UI Subviews
    
    private let scrollStack = ScrollStackView(
        axis: .vertical,
        horizontalInset: Constants.Style.DefaultHorizontalMargins
    )
    
    private lazy var noneButton: OptionButton        = makeOptionButton(for: .none)
    private lazy var aLittleButton: OptionButton     = makeOptionButton(for: .aLittle)
    private lazy var somewhatButton: OptionButton    = makeOptionButton(for: .somewhat)
    private lazy var stressedButton: OptionButton    = makeOptionButton(for: .stressed)
    private lazy var veryStressedButton: OptionButton = makeOptionButton(for: .veryStressed)
    
    private lazy var messages: [MessageInfo] = {
        let messages = Services.shared.storageServices.infoMessages?.messages(withLocation: .pageWeHaveNoticed)
        return messages ?? []
    }()
    
    private lazy var comingSoonItem = UIBarButtonItem(
        image: ImagePalette.templateImage(withName: .infoMessage),
        style: .plain,
        target: self,
        action: #selector(infoButtonPressed)
    )
    
    private lazy var closeButton: UIBarButtonItem = {
        let item = UIBarButtonItem(
            image: ImagePalette.templateImage(withName: .closeButton),
            style: .plain,
            target: self,
            action: #selector(closeTapped)
        )
        item.tintColor = ColorPalette.color(withType: .primaryText)
        return item
    }()
    
    private lazy var footerView: GenericButtonView = {
        // Choose “Confirm” text based on variant
        let buttonKey = StringsProvider.string(forKey: .noticedStepConfirmButton)
        
        let gv = GenericButtonView(withTextStyleCategory: .secondaryBackground(shadow: false))
        gv.setButtonText(buttonKey)
        gv.setButtonEnabled(enabled: false)
        gv.addTarget(target: self, action: #selector(confirmTapped))
        return gv
    }()
    
    // MARK: – State
    
    /// Tracks which StressLevel (if any) has been selected
    private var selectedLevel: StressLevel? {
        didSet {
            // Enable the Confirm button only if an option is selected
            footerView.setButtonEnabled(enabled: selectedLevel != nil)
        }
    }
    
    // MARK: – Init
    
    /// - Parameters:
    ///   - variant: indicates whether we are in “we have noticed” or standalone mode
    init(variant: FlowVariant) {
        self.variant = variant
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: – Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ColorPalette.color(withType: .secondary)
        setupNavigationBar()
        setupLayout()
        setupActions()
    }
    
    // MARK: – Setup Navigation Bar
    
    private func setupNavigationBar() {
        navigationController?.navigationBar.apply(
            style: NavigationBarStyleCategory.secondary(hidden: false).style
        )
        switch variant {
        case .embeddedInNoticed:
            addCustomBackButton()
            comingSoonItem.tintColor = ColorPalette.color(withType: .primary)
            self.navigationItem.rightBarButtonItem = (self.messages.count < 1)
                ? nil
                : comingSoonItem
        case .standalone:
            self.navigationItem.leftBarButtonItem = self.closeButton
        }
    }
    
    // MARK: – Layout Setup
    
    private func setupLayout() {
        
        let header = NSAttributedString(
            string: StringsProvider.string(forKey: .noticedStepElevenTitle),
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
        
        let messageKey = StringsProvider.string(forKey: .noticedStepElevenMessage)
        
        scrollStack.stackView.addLabel(
            withText: messageKey,
            fontStyle: .paragraph,
            color: ColorPalette.color(withType: .primaryText)
        )
        scrollStack.stackView.addBlankSpace(space: 36)
        
        [noneButton, aLittleButton, somewhatButton, stressedButton, veryStressedButton].forEach { btn in
            scrollStack.stackView.addArrangedSubview(btn)
            scrollStack.stackView.addBlankSpace(space: 16)
            btn.autoSetDimension(.height, toSize: 60)
        }
        
        view.addSubview(scrollStack)
        scrollStack.autoPinEdgesToSuperviewSafeArea(
            with: .zero,
            excludingEdge: .bottom
        )
        
        // 4) Footer “Confirm”
        view.addSubview(footerView)
        footerView.autoPinEdgesToSuperviewSafeArea(
            with: .zero,
            excludingEdge: .top
        )
        scrollStack.scrollView.autoPinEdge(
            .bottom,
            to: .top,
            of: footerView
        )
    }
    
    // MARK: – Helper to create an OptionButton for a given stress level
    
    private func makeOptionButton(for level: StressLevel) -> OptionButton {
        let btn = OptionButton()
        btn.layoutStyle = .horizontal(spacing: 16, horizontalAlignment: .leading)

        // Set title
        btn.setTitle(level.displayText, for: .normal)
        
        // Set icon (template + tint)
        let icon = ImagePalette.templateImage(withName: level.iconImageName)
        btn.setImage(icon, for: .normal)
        btn.imageView?.tintColor = ColorPalette.color(withType: .primary)
        
        return btn
    }
    
    // MARK: – Actions Setup
    
    private func setupActions() {
        noneButton.addTarget(self, action: #selector(optionTapped(_:)), for: .touchUpInside)
        aLittleButton.addTarget(self, action: #selector(optionTapped(_:)), for: .touchUpInside)
        somewhatButton.addTarget(self, action: #selector(optionTapped(_:)), for: .touchUpInside)
        stressedButton.addTarget(self, action: #selector(optionTapped(_:)), for: .touchUpInside)
        veryStressedButton.addTarget(self, action: #selector(optionTapped(_:)), for: .touchUpInside)
    }
    
    @objc private func optionTapped(_ sender: OptionButton) {
        // Deselect all first
        [noneButton, aLittleButton, somewhatButton, stressedButton, veryStressedButton].forEach { $0.isSelected = false }
        
        // Select the tapped one and update state
        if sender == noneButton {
            noneButton.isSelected = true
            selectedLevel = StressLevel.none
        } else if sender == aLittleButton {
            aLittleButton.isSelected = true
            selectedLevel = .aLittle
        } else if sender == somewhatButton {
            somewhatButton.isSelected = true
            selectedLevel = .somewhat
        } else if sender == stressedButton {
            stressedButton.isSelected = true
            selectedLevel = .stressed
        } else if sender == veryStressedButton {
            veryStressedButton.isSelected = true
            selectedLevel = .veryStressed
        }
    }
    
    @objc private func confirmTapped() {
        guard let level = selectedLevel else { return }
        delegate?.stressLevelViewController(self, didSelect: level)
    }
    
    @objc private func closeTapped() {
        delegate?.stressLevelViewControllerDidCancel(self)
    }
    
    @objc private func infoButtonPressed() {
        Services.shared.navigator.openMessagePage(withLocation: .pageWeHaveNoticed, presenter: self)
    }
}
