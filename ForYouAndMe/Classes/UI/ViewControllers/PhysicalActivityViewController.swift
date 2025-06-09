//
//  PhysicalActivityViewController.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 06/06/25.
//

import UIKit
import PureLayout

/// Delegate protocol to notify about the selected activity level or cancellation
protocol PhysicalActivityViewControllerDelegate: AnyObject {
    /// Called when the user selects an activity level and taps “Next”
    func physicalActivityViewController(_ vc: PhysicalActivityViewController,
                                        didSelect level: PhysicalActivityViewController.ActivityLevel)
    /// Called when the user taps the close (“X”) button
    func physicalActivityViewControllerDidCancel(_ vc: PhysicalActivityViewController)
}

/// A view controller that asks “Did you do any physical activity in the time just preceding the reading?”
/// and offers four options: No, Mild, Moderate, Vigorous.
class PhysicalActivityViewController: UIViewController {
    
    // MARK: – Public API
    
    /// The possible activity levels the user can choose
    enum ActivityLevel: String, Codable {
        case no        = "no"
        case mild      = "mild"
        case moderate  = "moderate"
        case vigorous  = "vigouros"
        
        /// Returns the localized display text for each activity level
        var displayText: String {
            switch self {
            case .no:
                return StringsProvider.string(forKey: .noticedStepTenFirstButton)
            case .mild:
                return StringsProvider.string(forKey: .noticedStepTenSecondButton)
            case .moderate:
                return StringsProvider.string(forKey: .noticedStepTenThirdButton)
            case .vigorous:
                return StringsProvider.string(forKey: .noticedStepTenFourthButton)
            }
        }
        
        /// Returns the name of the icon image (template) for each level
        var iconImageName: TemplateImageName {
            switch self {
            case .no:
                return .activityIconNo
            case .mild:
                return .activityIconMild
            case .moderate:
                return .activityIconModerate
            case .vigorous:
                return .activityIconVigorous
            }
        }
    }
    
    weak var delegate: PhysicalActivityViewControllerDelegate?
    
    // MARK: – Flow Variant
    
    /// Indicates whether this controller is running in “standalone” vs “noticed” mode.
    private let variant: FlowVariant
    
    // MARK: – UI Subviews
    
    private let scrollStack = ScrollStackView(
        axis: .vertical,
        horizontalInset: Constants.Style.DefaultHorizontalMargins
    )
    
    private lazy var noButton: OptionButton      = makeOptionButton(for: .no)
    private lazy var mildButton: OptionButton    = makeOptionButton(for: .mild)
    private lazy var moderateButton: OptionButton = makeOptionButton(for: .moderate)
    private lazy var vigorousButton: OptionButton = makeOptionButton(for: .vigorous)
    
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
        // Decide which “Next” button text to use based on variant
        let buttonKey = StringsProvider.string(forKey: .noticedStepNextButton)
        let gv = GenericButtonView(withTextStyleCategory: .secondaryBackground(shadow: false))
        gv.setButtonText(buttonKey)
        gv.setButtonEnabled(enabled: false)
        gv.addTarget(target: self, action: #selector(nextTapped))
        return gv
    }()
    
    // MARK: – State
    
    /// Tracks which ActivityLevel (if any) has been selected
    private var selectedLevel: ActivityLevel? {
        didSet {
            // Enable the Next button only if an option is selected
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
        case .standalone:
            self.navigationItem.leftBarButtonItem = self.closeButton
        }
    }
    
    // MARK: – Layout Setup
    
    private func setupLayout() {
        
        let header = NSAttributedString(
            string: StringsProvider.string(forKey: .noticedStepTenTitle),
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
        
        let messageKey = StringsProvider.string(forKey: .noticedStepTenMessage)
        
        scrollStack.stackView.addLabel(
            withText: messageKey,
            fontStyle: .paragraph,
            color: ColorPalette.color(withType: .primaryText)
        )
        scrollStack.stackView.addBlankSpace(space: 36)
        
        [noButton, mildButton, moderateButton, vigorousButton].forEach { btn in
            scrollStack.stackView.addArrangedSubview(btn)
            scrollStack.stackView.addBlankSpace(space: 16)
            btn.autoSetDimension(.height, toSize: 60)
        }
        
        view.addSubview(scrollStack)
        scrollStack.autoPinEdgesToSuperviewSafeArea(
            with: .zero,
            excludingEdge: .bottom
        )
        
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
    
    // MARK: – Helper to create an OptionButton for a given level
    
    private func makeOptionButton(for level: ActivityLevel) -> OptionButton {
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
        noButton.addTarget(self, action: #selector(optionTapped(_:)), for: .touchUpInside)
        mildButton.addTarget(self, action: #selector(optionTapped(_:)), for: .touchUpInside)
        moderateButton.addTarget(self, action: #selector(optionTapped(_:)), for: .touchUpInside)
        vigorousButton.addTarget(self, action: #selector(optionTapped(_:)), for: .touchUpInside)
    }
    
    @objc private func optionTapped(_ sender: OptionButton) {
        // Deselect all first
        [noButton, mildButton, moderateButton, vigorousButton].forEach { $0.isSelected = false }
        
        // Select the tapped one and update state
        if sender == noButton {
            noButton.isSelected = true
            selectedLevel = .no
        } else if sender == mildButton {
            mildButton.isSelected = true
            selectedLevel = .mild
        } else if sender == moderateButton {
            moderateButton.isSelected = true
            selectedLevel = .moderate
        } else if sender == vigorousButton {
            vigorousButton.isSelected = true
            selectedLevel = .vigorous
        }
    }
    
    @objc private func nextTapped() {
        guard let level = selectedLevel else { return }
        delegate?.physicalActivityViewController(self, didSelect: level)
    }
    
    @objc private func closeTapped() {
        delegate?.physicalActivityViewControllerDidCancel(self)
    }
}
