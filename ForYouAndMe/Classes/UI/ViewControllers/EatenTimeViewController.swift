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
    
    var selectedType: EatenTypeViewController.EntryType
    
    enum TimeRelative: String {
        case withinHour = "In the last hour"
        case earlier    = "Earlier than the last hour"
    }
    
    private lazy var withinHourButton: OptionButton = makeOptionButton(type: .withinHour)
    private lazy var earlierButton: OptionButton     = makeOptionButton(type: .earlier)
    
    weak var delegate: EatenTimeViewControllerDelegate?
    
    private lazy var footerView: GenericButtonView = {
        let buttonView = GenericButtonView(withTextStyleCategory: .secondaryBackground(shadow: false))
        buttonView.setButtonText(StringsProvider.string(forKey: .spiroNext))
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
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    init(selectedType: EatenTypeViewController.EntryType) {
        self.selectedType = selectedType
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
        
        let scrollStackView = ScrollStackView(axis: .vertical, horizontalInset: Constants.Style.DefaultHorizontalMargins)
        self.view.addSubview(scrollStackView)
        scrollStackView.autoPinEdgesToSuperviewSafeArea(with: .zero, excludingEdge: .bottom)
        
        let baseText = "You had you"
        let typeText = " " + selectedType.rawValue.lowercased() + "..."
        
        let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center

        let attrsNormal: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 17),
            .foregroundColor: ColorPalette.color(withType: .primaryText),
            .paragraphStyle: paragraphStyle
        ]
        let attributed = NSMutableAttributedString(string: baseText, attributes: attrsNormal)
        
        let attrsBold: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 17),
            .foregroundColor: ColorPalette.color(withType: .primaryText),
            .paragraphStyle: paragraphStyle
        ]
        attributed.append(.init(string: typeText, attributes: attrsBold))
        
        // Transform input text to bold using attributed string
        let baseTitle = "I've eaten"
        let boldAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: FontPalette.fontStyleData(forStyle: .header2).font.pointSize),
            .foregroundColor: ColorPalette.color(withType: .primaryText),
            .paragraphStyle: paragraphStyle
        ]
        let boldString = NSAttributedString(string: baseTitle, attributes: boldAttrs)
        scrollStackView.stackView.addLabel(attributedString: boldString, numberOfLines: 1)
        
        scrollStackView.stackView.addBlankSpace(space: 36)
        
        scrollStackView.stackView.addLabel(attributedString: attributed,
                                           numberOfLines: 1)
        
        scrollStackView.stackView.addBlankSpace(space: 44)
        
        scrollStackView.stackView.addArrangedSubview(self.earlierButton)
        
        scrollStackView.stackView.addBlankSpace(space: 16)
        
        scrollStackView.stackView.addArrangedSubview(self.withinHourButton)
        
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
        btn.layoutStyle = .textLeft(padding: 16)
        btn.setTitle(type.rawValue, for: .normal)
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
}
