//
//  PossibleAnswerTableViewCell.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 11/06/2020.
//

import UIKit
import PureLayout

class PossibleAnswerTableViewCell: UITableViewCell {
    
    typealias PossibleAnswerCallback = NotificationCallback
    
    fileprivate static let optionWidth: CGFloat = 74.0
    private var isOther: Bool = false
    private var otherAnswerChangedCallback: ((String) -> Void)?
    private var answerPressedCallback: PossibleAnswerCallback?
    
    private lazy var answerLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        return label
    }()
    
    private lazy var button: UIButton = {
        let button = UIButton()
        button.contentEdgeInsets = UIEdgeInsets(top: 8.0, left: 8.0, bottom: 8.0, right: 8.0)
        button.addTarget(self, action: #selector(self.buttonPressed), for: .touchUpInside)
        return button
    }()
    
    private lazy var otherTextFieldView: GenericTextFieldView = {
        let view = GenericTextFieldView(keyboardType: .default, styleCategory: .secondary)
        view.delegate = self
        view.textField.attributedPlaceholder = NSAttributedString(
            string: StringsProvider.string(forKey: .placeholderOtherField),
            attributes: [
                .foregroundColor: ColorPalette.color(withType: .secondaryText).applyAlpha(0.5)
            ]
        )
        view.isHidden = true
        return view
    }()
        
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.separatorInset = UIEdgeInsets(top: 0.0,
                                           left: Constants.Style.DefaultHorizontalMargins,
                                           bottom: 0.0,
                                           right: Constants.Style.DefaultHorizontalMargins)
        self.selectionStyle = .none
        self.backgroundColor = .clear
        
//        let horizontalStackView = UIStackView()
//        horizontalStackView.axis = .horizontal
//        
//        // Label
//        let answerContainerView = UIView()
//        answerContainerView.addSubview(self.answerLabel)
//        self.answerLabel.autoPinEdge(toSuperviewEdge: .leading)
//        self.answerLabel.autoPinEdge(toSuperviewEdge: .trailing)
//        self.answerLabel.autoPinEdge(toSuperviewEdge: .top, withInset: 0, relation: .greaterThanOrEqual)
//        self.answerLabel.autoPinEdge(toSuperviewEdge: .bottom, withInset: 0, relation: .greaterThanOrEqual)
//        self.answerLabel.autoAlignAxis(toSuperviewAxis: .horizontal)
//        horizontalStackView.addArrangedSubview(answerContainerView)
//        
//        // button
//        let buttonContainerView = UIView()
//        buttonContainerView.addSubview(self.button)
//        buttonContainerView.autoSetDimension(.width, toSize: Self.optionWidth)
//        self.button.autoPinEdge(toSuperviewEdge: .leading)
//        self.button.autoPinEdge(toSuperviewEdge: .trailing)
//        self.button.autoPinEdge(toSuperviewEdge: .top, withInset: 0, relation: .greaterThanOrEqual)
//        self.button.autoPinEdge(toSuperviewEdge: .bottom, withInset: 0, relation: .greaterThanOrEqual)
//        self.button.autoAlignAxis(toSuperviewAxis: .horizontal)
//        horizontalStackView.addArrangedSubview(buttonContainerView)
//        
//        self.contentView.addSubview(horizontalStackView)
//        horizontalStackView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 0.0,
//                                                                            left: Constants.Style.DefaultHorizontalMargins,
//                                                                            bottom: 24.0,
//                                                                            right: 0.0))
//
//        self.contentView.addSubview(self.otherTextFieldView)
//        self.otherTextFieldView.autoPinEdge(.top, to: .bottom, of: horizontalStackView, withOffset: 8.0)
//        self.otherTextFieldView.autoPinEdge(toSuperviewEdge: .leading, withInset: Constants.Style.DefaultHorizontalMargins)
//        self.otherTextFieldView.autoPinEdge(toSuperviewEdge: .trailing, withInset: Constants.Style.DefaultHorizontalMargins)
//        self.otherTextFieldView.autoPinEdge(toSuperviewEdge: .bottom, withInset: 8.0)
        
        // Vertical stack
        let verticalStackView = UIStackView()
        verticalStackView.axis = .vertical
        verticalStackView.spacing = 8
        verticalStackView.alignment = .fill
        
        // Horizontal stack: label + button
        let horizontalStackView = UIStackView()
        horizontalStackView.axis = .horizontal
        horizontalStackView.spacing = 0
        horizontalStackView.alignment = .center

        // Answer label container
        let answerContainerView = UIView()
        answerContainerView.addSubview(self.answerLabel)
        self.answerLabel.autoPinEdgesToSuperviewEdges()
        horizontalStackView.addArrangedSubview(answerContainerView)
        
        // Button container
        let buttonContainerView = UIView()
        buttonContainerView.autoSetDimension(.width, toSize: Self.optionWidth)
        buttonContainerView.addSubview(self.button)
        self.button.autoPinEdgesToSuperviewEdges()
        horizontalStackView.addArrangedSubview(buttonContainerView)
        
        // Add both rows to vertical stack
        verticalStackView.addArrangedSubview(horizontalStackView)
        verticalStackView.addArrangedSubview(self.otherTextFieldView)
        
        // Add to contentView
        self.contentView.addSubview(verticalStackView)
        verticalStackView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(
            top: 0,
            left: Constants.Style.DefaultHorizontalMargins,
            bottom: 24.0,
            right: 0
        ))
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Public Methods
    
    func display(data: PossibleAnswer,
                 isSelected: Bool,
                 isOther: Bool = false,
                 otherText: String? = nil,
                 answerPressedCallback: @escaping PossibleAnswerCallback,
                 otherAnswerChangedCallback: ((String) -> Void)? = nil) {

        self.answerPressedCallback = answerPressedCallback
        self.otherAnswerChangedCallback = otherAnswerChangedCallback
        self.isOther = isOther

        self.answerLabel.attributedText = NSAttributedString.create(
            withText: data.text,
            fontStyle: .paragraph,
            colorType: .secondaryText,
            textAlignment: .left)
        
        if isSelected {
            self.button.setImage(ImagePalette.templateImage(withName: .radioButtonFilled), for: .normal)
            self.button.imageView?.tintColor = ColorPalette.color(withType: .secondary)
            self.otherTextFieldView.isHidden = !isOther
        } else {
            self.button.setImage(ImagePalette.templateImage(withName: .radioButtonOutline), for: .normal)
            self.button.imageView?.tintColor = ColorPalette.color(withType: .secondary).applyAlpha(0.5)
            self.otherTextFieldView.isHidden = true
        }
        
        self.otherTextFieldView.text = otherText ?? ""
    }
    
    // MARK: - Actions
    
    @objc private func buttonPressed() {
        self.answerPressedCallback?()
    }
}

extension PossibleAnswerTableViewCell: GenericTextFieldViewDelegate {
    func genericTextFieldShouldReturn(textField: GenericTextFieldView) -> Bool {
        return self.endEditing(true)
    }
    
    func genericTextFieldDidChange(textField: GenericTextFieldView) {
        if isOther {
            self.otherAnswerChangedCallback?(textField.text)
        }
    }
}
