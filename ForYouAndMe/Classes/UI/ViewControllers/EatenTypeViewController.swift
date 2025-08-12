//
//  EatenTypeViewController.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 14/05/25.
//

import UIKit
import PureLayout

protocol EatenTypeViewControllerDelegate: AnyObject {
    func eatenTypeViewController(_ vc: EatenTypeViewController, didSelect type: FoodEntryType)
    func eatenDismiss(_ vc: EatenTypeViewController)
}

class EatenTypeViewController: UIViewController {

    weak var delegate: EatenTypeViewControllerDelegate?
    var alert: Alert?

    private lazy var snackButton = makeOptionButton(type: .snack)
    private lazy var mealButton  = makeOptionButton(type: .meal)
    private let storage: CacheService
    private let navigator: AppNavigator
    private let variant: FlowVariant
    
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
    
    private var isStandalone: Bool {
        if case .standalone = variant {
            return true
        } else {
            return false
        }
    }
    
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
    
    private lazy var footerView: GenericButtonView = {
        let buttonView = GenericButtonView(withTextStyleCategory: .secondaryBackground(shadow: false))
        let text = isStandalone
        ? StringsProvider.string(forKey: .diaryNoteEatenNextButton)
        : StringsProvider.string(forKey: .noticedStepNextButton)
        buttonView.setButtonText(text)
        buttonView.setButtonEnabled(enabled: false)
        buttonView.addTarget(target: self, action: #selector(self.nextTapped))
        
        return buttonView
    }()
    
    private lazy var messages: [MessageInfo] = {
        let location: MessageInfoParameter = isStandalone ? .pageIHaveEeaten : .pageWeHaveNoticed
        let messages = self.storage.infoMessages?.messages(withLocation: location)
        return messages ?? []
    }()
    
    private var selectedType: FoodEntryType? {
        didSet {
            let enabled = selectedType != nil
            self.footerView.setButtonEnabled(enabled: enabled)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = ColorPalette.color(withType: .secondary)
        setupLayout()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.apply(
            style: NavigationBarStyleCategory.secondary(hidden: false).style
        )
        switch variant {
        case .embeddedInNoticed:
            addCustomBackButton()
        case .standalone, .fromChart(_):
            self.navigationItem.leftBarButtonItem = self.closeButton
        }
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
        
        // Transform input text to bold using attributed string
        
        let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
        
        let text = isStandalone
        ? StringsProvider.string(forKey: .diaryNoteEatenStepOneTitle)
        : StringsProvider.string(forKey: .noticedStepFiveTitle)
        
        let baseTitle = text
        let boldAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: FontPalette.fontStyleData(forStyle: .header2).font.pointSize),
            .foregroundColor: ColorPalette.color(withType: .primaryText),
            .paragraphStyle: paragraphStyle
        ]
        let boldString = NSAttributedString(string: baseTitle, attributes: boldAttrs)
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
        
        let message = isStandalone
        ? StringsProvider.string(forKey: .diaryNoteEatenStepOneMessage)
        : StringsProvider.string(forKey: .noticedStepFiveMessage)
        
        scrollStackView.stackView.addLabel(withText: message,
                               fontStyle: .paragraph,
                               color: ColorPalette.color(withType: .primaryText))
        
        scrollStackView.stackView.addBlankSpace(space: 44)
        let containerButtonView = UIStackView.create(withAxis: .horizontal, spacing: 20)
        containerButtonView.addArrangedSubview(snackButton)
        containerButtonView.addArrangedSubview(mealButton)
        
        scrollStackView.stackView.addArrangedSubview(containerButtonView)

        self.snackButton.autoSetDimensions(to: CGSize(width: 115, height: 118))

        self.mealButton.autoAlignAxis(.horizontal, toSameAxisOf: snackButton)
        self.mealButton.autoMatch(.width, to: .width, of: snackButton)
        self.mealButton.autoMatch(.height, to: .height, of: snackButton)
        
        // Footer
        self.view.addSubview(self.footerView)
        footerView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets.zero, excludingEdge: .top)
        scrollStackView.scrollView.autoPinEdge(.bottom, to: .top, of: footerView)
    }

    private func makeOptionButton(type: FoodEntryType) -> OptionButton {
        let btn = OptionButton()
        btn.layoutStyle = .vertical(spacing: 16)
        let imageName = type == .snack ? TemplateImageName.snackImage : TemplateImageName.mealImage
        let title = type.displayTextUsingVariant(variant: self.variant)
        
        btn.setImage(ImagePalette.templateImage(withName: imageName), for: .normal)
        btn.setTitle(title, for: .normal)
        btn.addTarget(self, action: #selector(optionTapped(_:)), for: .touchUpInside)
        return btn
    }

    @objc private func optionTapped(_ sender: UIButton) {
        snackButton.isSelected = (sender == snackButton)
        mealButton.isSelected  = (sender == mealButton)
        selectedType = (sender == snackButton) ? .snack : .meal
    }

    @objc private func nextTapped() {
        guard let type = selectedType else { return }
        delegate?.eatenTypeViewController(self, didSelect: type)
    }

    // MARK: Actions
    @objc private func closeButtonPressed() {
        self.delegate?.eatenDismiss(self)
    }

    @objc private func infoButtonPressed() {
        let location: MessageInfoParameter = isStandalone ? .pageIHaveEeaten : .pageWeHaveNoticed
        self.navigator.openMessagePage(withLocation: location, presenter: self)
    }
}
