//
//  NutrientQuestionViewController.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 16/05/25.
//

import UIKit

protocol NutrientQuestionViewControllerDelegate: AnyObject {
    /// Called when user confirms the nutrient answer (Yes/No)
    func nutrientQuestionViewController(_ vc: NutrientQuestionViewController,
                                        didAnswer hasNutrients: Bool)
    /// Called when user taps back
    func nutrientQuestionViewControllerDidCancel(_ vc: NutrientQuestionViewController)
}

class NutrientQuestionViewController: UIViewController {
    
    // MARK: - Public API
    
    /// The food type (snack/meal) to display in title
    var selectedType: EatenTypeViewController.EntryType!
    private let storage: CacheService
    private let navigator: AppNavigator
    private let variant: FlowVariant
    weak var delegate: NutrientQuestionViewControllerDelegate?
    
    // MARK: - Subviews
    
    private let scrollStack = ScrollStackView(
        axis: .vertical,
        horizontalInset: Constants.Style.DefaultHorizontalMargins
    )
    
    private lazy var yesButton: OptionButton = makeOption(text: (variant == .standalone)
                                                          ? StringsProvider.string(forKey: .diaryNoteEatenStepFifthFirstButton)
                                                          : StringsProvider.string(forKey: .noticedStepNineFirstButton))
    private lazy var noButton: OptionButton = makeOption(text: (variant == .standalone)
                                                         ? StringsProvider.string(forKey: .diaryNoteEatenStepFifthSecondButton)
                                                         : StringsProvider.string(forKey: .noticedStepNineSecondButton))
    
    private lazy var footerView: GenericButtonView = {
        let buttonView = GenericButtonView(withTextStyleCategory: .secondaryBackground(shadow: false))
        let buttonKey = (variant == .standalone)
        ? StringsProvider.string(forKey: .diaryNoteEatenConfirmButton)
        : StringsProvider.string(forKey: .noticedStepConfirmButton)
        buttonView.setButtonText(buttonKey)
        buttonView.setButtonEnabled(enabled: false)
        buttonView.addTarget(target: self, action: #selector(self.confirmTapped))
        
        return buttonView
    }()
    
    // MARK: - State
    
    private var selectedAnswer: Bool? {
        didSet {
            footerView.setButtonEnabled(enabled: selectedAnswer != nil)
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
    
    // MARK: - Setup
    
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
        
        // Title: attributed string
        let messageKey = (variant == .standalone)
        ? StringsProvider.string(forKey: .diaryNoteEatenStepFifthMessage)
        : StringsProvider.string(forKey: .noticedStepNineMessage)
        
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center

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
        
        let att = NSMutableAttributedString(string: messageKey, attributes: normalAttrs)
        
        func applyBold(to substring: String) {
            let fullText = att.string as NSString
            let range = fullText.range(of: substring, options: .caseInsensitive)
            guard range.location != NSNotFound else { return }
            att.addAttributes(boldAttrs, range: range)
        }
        
        let typeKey = selectedType.rawValue    // e.g. "Snack" or "Meal"
        applyBold(to: typeKey)
        ["protein", "fiber", "fat"].forEach { applyBold(to: $0) }
        
        let baseTitle = (variant == .standalone)
        ? StringsProvider.string(forKey: .diaryNoteEatenStepFifthTitle)
        : StringsProvider.string(forKey: .noticedStepNineTitle)
        let boldAttrsTitle: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: FontPalette.fontStyleData(forStyle: .header2).font.pointSize),
            .foregroundColor: ColorPalette.color(withType: .primaryText),
            .paragraphStyle: paragraph
        ]
        let boldString = NSAttributedString(string: baseTitle, attributes: boldAttrsTitle)
        scrollStack.stackView.addLabel(attributedString: boldString, numberOfLines: 1)
        
        scrollStack.stackView.addBlankSpace(space: 36)
        
        scrollStack.stackView.addLabel(attributedString: att)
        scrollStack.stackView.addBlankSpace(space: 24)
        
        // Buttons
        [yesButton, noButton].forEach { btn in
            scrollStack.stackView.addArrangedSubview(btn)
            scrollStack.stackView.addBlankSpace(space: 16)
            btn.autoSetDimension(.height, toSize: 54)
        }
        
        // Footer
        view.addSubview(footerView)
        footerView.autoPinEdgesToSuperviewSafeArea(with: .zero, excludingEdge: .top)
        scrollStack.scrollView.autoPinEdge(.bottom, to: .top, of: footerView)
    }
    
    private func makeOption(text: String) -> OptionButton {
        let btn = OptionButton()
        btn.layoutStyle = .textLeft(padding: 16)
        btn.setTitle(text, for: .normal)
        return btn
    }
    
    private func setupActions() {
        yesButton.addTarget(self, action: #selector(optionTapped(_:)), for: .touchUpInside)
        noButton .addTarget(self, action: #selector(optionTapped(_:)), for: .touchUpInside)
    }
    
    // MARK: - Actions
    
    @objc private func optionTapped(_ sender: OptionButton) {
        yesButton.isSelected = (sender == yesButton)
        noButton .isSelected = (sender == noButton)
        selectedAnswer = (sender == yesButton)
    }
    
    @objc private func confirmTapped() {
        guard let answer = selectedAnswer else { return }
        delegate?.nutrientQuestionViewController(self, didAnswer: answer)
    }
    
    @objc private func infoButtonPressed() {
        let location: MessageInfoParameter = (variant == .embeddedInNoticed) ? .pageWeHaveNoticed : .pageIHaveEeaten
        self.navigator.openMessagePage(withLocation: location, presenter: self)
    }
}
