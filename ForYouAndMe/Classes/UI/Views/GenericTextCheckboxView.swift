//
//  GenericTextCheckboxView.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 02/07/2020.
//

import UIKit
import RxCocoa

enum GenericTextCheckboxStyleCategory: StyleCategory {
    case primary(fontStyle: FontStyle, textFirst: Bool)
    case secondary(fontStyle: FontStyle, textFirst: Bool)
    
    var style: Style<GenericTextCheckboxView> {
        switch self {
        case .primary(let fontStyle, _): return Style<GenericTextCheckboxView> { textCheckboxView in
            textCheckboxView.labelAttributedTextStyle = AttributedTextStyle(fontStyle: fontStyle,
                                                                            colorType: .primaryText,
                                                                            textAlignment: .left)
            }
        case .secondary(let fontStyle, _): return Style<GenericTextCheckboxView> { textCheckboxView in
            textCheckboxView.labelAttributedTextStyle = AttributedTextStyle(fontStyle: fontStyle,
                                                                            colorType: .secondaryText,
                                                                            textAlignment: .left)
            }
        }
    }
    
    var checkboxStyleCategory: GenericCheckboxStyleCategory {
        switch self {
        case .primary: return .primary
        case .secondary: return .secondary
        }
    }
    
    var textFirst: Bool {
        switch self {
        case .primary(_, let textFirst): return textFirst
        case .secondary(_, let textFirst): return textFirst
        }
    }
}

class GenericTextCheckboxView: UIView {
    
    public var isCheckedSubject: BehaviorRelay<Bool> { self.checkBox.isCheckedSubject }
    
    fileprivate var labelAttributedTextStyle: AttributedTextStyle?
    
    private let checkBox: GenericCheckboxView
    
    private var label: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        return label
    }()
    
    init(isDefaultChecked: Bool, styleCategory: GenericTextCheckboxStyleCategory) {
        self.checkBox = GenericCheckboxView(isDefaultChecked: isDefaultChecked, styleCategory: styleCategory.checkboxStyleCategory)
        super.init(frame: .zero)
        let horizontalStackView = UIStackView()
        horizontalStackView.axis = .horizontal
        horizontalStackView.spacing = 8.0
        self.addSubview(horizontalStackView)
        horizontalStackView.autoPinEdgesToSuperviewEdges()
        
        let checkboxContainerView = UIView()
        checkboxContainerView.addSubview(self.checkBox)
        
        self.checkBox.autoPinEdge(toSuperviewEdge: .leading)
        self.checkBox.autoPinEdge(toSuperviewEdge: .trailing)
        self.checkBox.autoPinEdge(toSuperviewEdge: .top, withInset: 0.0, relation: .greaterThanOrEqual)
        self.checkBox.autoPinEdge(toSuperviewEdge: .bottom, withInset: 0.0, relation: .greaterThanOrEqual)
        self.checkBox.autoAlignAxis(toSuperviewAxis: .horizontal)
        
        if styleCategory.textFirst {
            horizontalStackView.addArrangedSubview(self.label)
            horizontalStackView.addArrangedSubview(checkboxContainerView)
        } else {
            horizontalStackView.addArrangedSubview(checkboxContainerView)
            horizontalStackView.addArrangedSubview(self.label)
        }
        
        self.apply(style: styleCategory.style)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Public Methods
    
    public func setLabelText(_ text: String) {
        guard let attributedTextStyle = self.labelAttributedTextStyle else {
            assertionFailure("Setting a text without attributed text style")
            return
        }
        let attributedText = NSAttributedString.create(withText: text, attributedTextStyle: attributedTextStyle)
        self.label.attributedText = attributedText
    }
    
    public func updateCheckBox(_ checked: Bool) {
        self.checkBox.updateCheckBox(checked)
    }
}
