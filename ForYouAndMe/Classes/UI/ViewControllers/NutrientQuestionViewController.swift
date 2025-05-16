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
    weak var delegate: NutrientQuestionViewControllerDelegate?
    
    // MARK: - Subviews
    
    private let scrollStack = ScrollStackView(
        axis: .vertical,
        horizontalInset: Constants.Style.DefaultHorizontalMargins
    )
    
    private lazy var yesButton: OptionButton = makeOption(text: "Yes")
    private lazy var noButton: OptionButton = makeOption(text: "No")
    
    private lazy var footerView: GenericButtonView = {
        let buttonView = GenericButtonView(withTextStyleCategory: .secondaryBackground(shadow: false))
        buttonView.setButtonText(StringsProvider.string(forKey: .spiroNext))
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
    
    // MARK: - Lifecycle
    
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
        view.addSubview(scrollStack)
        scrollStack.autoPinEdgesToSuperviewSafeArea(with: .zero, excludingEdge: .bottom)
        
        // Title: attributed string
        let base = "Did your "
        let bold = selectedType.rawValue.lowercased()
        let tail = " contain either a significant proportion of protein, fiber and/or fat in it?"
        
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
        let att = NSMutableAttributedString(string: base, attributes: normalAttrs)
        att.append(NSAttributedString(string: bold, attributes: boldAttrs))
        att.append(NSAttributedString(string: tail, attributes: normalAttrs))
        
        let baseTitle = "I've eaten"
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
}
