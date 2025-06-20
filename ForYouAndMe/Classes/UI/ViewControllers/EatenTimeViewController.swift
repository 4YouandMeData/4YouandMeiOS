//
//  EatenTimeViewController.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 15/05/25.
//

import UIKit
import PureLayout

protocol EatenTimeViewControllerDelegate: AnyObject {
    func eatenTimeViewController(_ vc: EatenTimeViewController, didSelect relative: EatenTimeViewController.TimeRelative)
}

class EatenTimeViewController: UIViewController {
    
    var selectedType: FoodEntryType
    var alert: Alert?
    
    private let storage: CacheService
    private let navigator: AppNavigator
    private let variant: FlowVariant
    
    enum TimeRelative: String {
        case withinHour
        case earlier
        
        func displayTextWithVariant(variant: FlowVariant) -> String {
            switch variant {
            case .embeddedInNoticed:
                switch self {
                case .earlier:
                    return StringsProvider.string(forKey: .noticedStepSixSecondButton)
                case .withinHour:
                    return StringsProvider.string(forKey: .noticedStepSixFirstButton)
                }
                
            case .standalone:
                switch self {
                case .earlier:
                    return StringsProvider.string(forKey: .diaryNoteEatenStepTwoSecondButton)
                case .withinHour:
                    return StringsProvider.string(forKey: .diaryNoteEatenStepTwoFirstButton)
                }
            }
        }
    }
    
    private lazy var withinHourButton: OptionButton = makeOptionButton(type: .withinHour)
    private lazy var earlierButton: OptionButton = makeOptionButton(type: .earlier)
    
    weak var delegate: EatenTimeViewControllerDelegate?
    
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
    
    private var selectedRelative: TimeRelative? {
        didSet {
            let enabled = (selectedRelative != nil)
            footerView.setButtonEnabled(enabled: enabled)
        }
    }
    
    private lazy var messages: [MessageInfo] = {
        let location: MessageInfoParameter = (variant == .embeddedInNoticed) ? .pageWeHaveNoticed : .pageIHaveEeaten
        let messages = self.storage.infoMessages?.messages(withLocation: location)
        return messages ?? []
    }()
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    init(selectedType: FoodEntryType,
         variant: FlowVariant) {
        self.selectedType = selectedType
        self.navigator = Services.shared.navigator
        self.storage = Services.shared.storageServices
        self.variant = variant
        super.init(nibName: nil, bundle: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = ColorPalette.color(withType: .secondary)
        setupLayout()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.secondary(hidden: false).style)
        self.addCustomBackButton()
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
        
        let scrollStackView = ScrollStackView(axis: .vertical, horizontalInset: Constants.Style.DefaultHorizontalMargins)
        self.view.addSubview(scrollStackView)
        scrollStackView.autoPinEdgesToSuperviewSafeArea(with: .zero, excludingEdge: .bottom)
        
        let replacementString = selectedType.displayTextUsingVariant(variant: self.variant).lowercased()

        let messageKey = (variant == .standalone)
            ? StringsProvider.string(forKey: .diaryNoteEatenStepTwoMessage)
                .replacingPlaceholders(with: [replacementString])
            : StringsProvider.string(forKey: .noticedStepSixMessage)
            .replacingPlaceholders(with: [replacementString])

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let attrsNormal: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 17),
            .foregroundColor: ColorPalette.color(withType: .primaryText),
            .paragraphStyle: paragraphStyle
        ]

        let attributed = NSMutableAttributedString(string: messageKey, attributes: attrsNormal)

        let attrsBold: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 17),
            .foregroundColor: ColorPalette.color(withType: .primaryText),
            .paragraphStyle: paragraphStyle
        ]

        // Find the range of the string to be bolded
        if let boldRange = messageKey.range(of: replacementString) {
            let nsRange = NSRange(boldRange, in: messageKey)
            attributed.addAttributes(attrsBold, range: nsRange)
        }
        
        // Transform input text to bold using attributed string
        let titleKey = (variant == .standalone)
        ? StringsProvider.string(forKey: .diaryNoteEatenStepTwoTitle)
        : StringsProvider.string(forKey: .noticedStepSixTitle)
        
        let boldAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: FontPalette.fontStyleData(forStyle: .header2).font.pointSize),
            .foregroundColor: ColorPalette.color(withType: .primaryText),
            .paragraphStyle: paragraphStyle
        ]
        let boldString = NSAttributedString(string: titleKey, attributes: boldAttrs)
        scrollStackView.stackView.addLabel(attributedString: boldString, numberOfLines: 1)
        
        scrollStackView.stackView.addBlankSpace(space: 36)
        
        if let alert = alert?.body {
            scrollStackView.stackView.addLabel(
                withText: alert,
                fontStyle: .paragraph,
                color: ColorPalette.color(withType: .primaryText)
            )
            scrollStackView.stackView.addBlankSpace(space: 40)
        }
        
        scrollStackView.stackView.addLabel(attributedString: attributed,
                                           numberOfLines: 0)
        
        scrollStackView.stackView.addBlankSpace(space: 44)
        
        scrollStackView.stackView.addArrangedSubview(self.withinHourButton)
        
        scrollStackView.stackView.addBlankSpace(space: 16)
        
        scrollStackView.stackView.addArrangedSubview(self.earlierButton)
        
        self.earlierButton.autoSetDimension(.height, toSize: 54)
        self.withinHourButton.autoMatch(.height, to: .height, of: earlierButton)
        
        // Footer
        self.view.addSubview(self.footerView)
        footerView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets.zero, excludingEdge: .top)
        scrollStackView.scrollView.autoPinEdge(.bottom, to: .top, of: footerView)
    }
    
    // Private Methods
    
    private func makeOptionButton(type: TimeRelative) -> OptionButton {
        let btn = OptionButton()
        let title = type.displayTextWithVariant(variant: self.variant)
        btn.layoutStyle = .textLeft(padding: 16)
        btn.setTitle(title, for: .normal)
        btn.addTarget(self, action: #selector(optionTapped(_:)), for: .touchUpInside)
        return btn
    }
    
    // Action Methods
    
    @objc private func optionTapped(_ sender: OptionButton) {
        // Deselect both, then select the tapped one
        withinHourButton.isSelected = (sender == withinHourButton)
        earlierButton.isSelected     = (sender == earlierButton)
        selectedRelative = (sender == withinHourButton) ? .withinHour : .earlier
    }
    
    @objc private func nextTapped() {
        // Notify delegate when Next is tapped
        guard let rel = selectedRelative else { return }
        delegate?.eatenTimeViewController(self, didSelect: rel)
    }
    
    @objc private func infoButtonPressed() {
        let location: MessageInfoParameter = (variant == .embeddedInNoticed) ? .pageWeHaveNoticed : .pageIHaveEeaten
        self.navigator.openMessagePage(withLocation: location, presenter: self)
    }
}
