//
//  EatenTypeViewController.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 14/05/25.
//

import UIKit
import PureLayout

protocol EatenTypeViewControllerDelegate: AnyObject {
    func eatenTypeViewController(_ vc: EatenTypeViewController, didSelect type: EatenTypeViewController.EntryType)
    func eatenDismiss(_ vc: EatenTypeViewController)
}

class EatenTypeViewController: UIViewController {
    
    enum EntryType: String {
        case snack = "Snack"
        case meal  = "Meal"
    }

    weak var delegate: EatenTypeViewControllerDelegate?

    private lazy var snackButton = makeOptionButton(type: .snack)
    private lazy var mealButton  = makeOptionButton(type: .meal)
    
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
        
        let buttonView = GenericButtonView(withTextStyleCategory: .secondaryBackground(shadow: false))
        buttonView.setButtonText(StringsProvider.string(forKey: .spiroNext))
        buttonView.setButtonEnabled(enabled: false)
        buttonView.addTarget(target: self, action: #selector(self.nextTapped))
        
        return buttonView
    }()
    
    private var selectedType: EntryType? {
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

    private func setupLayout() {

        self.navigationItem.leftBarButtonItem = self.closeButton
        
        let scrollStackView = ScrollStackView(axis: .vertical, horizontalInset: Constants.Style.DefaultHorizontalMargins)
        self.view.addSubview(scrollStackView)
        scrollStackView.autoPinEdgesToSuperviewSafeArea(with: .zero, excludingEdge: .bottom)
        
        // Transform input text to bold using attributed string
        
        let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center

        let baseTitle = "I've eaten"
        let boldAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: FontPalette.fontStyleData(forStyle: .header2).font.pointSize),
            .foregroundColor: ColorPalette.color(withType: .primaryText),
            .paragraphStyle: paragraphStyle
        ]
        let boldString = NSAttributedString(string: baseTitle, attributes: boldAttrs)
        scrollStackView.stackView.addLabel(attributedString: boldString, numberOfLines: 1)
        
        scrollStackView.stackView.addBlankSpace(space: 36)
        
        scrollStackView.stackView.addLabel(withText: "Do you have a snack or normal meal?",
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

    private func makeOptionButton(type: EntryType) -> OptionButton {
        let btn = OptionButton()
        btn.layoutStyle = .vertical(spacing: 16)
        let imageName = type == .snack ? TemplateImageName.snackImage : TemplateImageName.mealImage
        btn.setImage(ImagePalette.templateImage(withName: imageName), for: .normal)
        btn.setTitle(type.rawValue, for: .normal)
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

    @objc func handleInfo() {
        // Present info modal if needed
    }
}
