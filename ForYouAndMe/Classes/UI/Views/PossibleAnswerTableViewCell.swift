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
    
    private var answerPressedCallback: PossibleAnswerCallback?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.separatorInset = UIEdgeInsets(top: 0.0,
                                           left: Constants.Style.DefaultHorizontalMargins,
                                           bottom: 0.0,
                                           right: Constants.Style.DefaultHorizontalMargins)
        self.selectionStyle = .none
        self.backgroundColor = .clear
        
        let horizontalStackView = UIStackView()
        horizontalStackView.axis = .horizontal
        
        // Label
        let answerContainerView = UIView()
        answerContainerView.addSubview(self.answerLabel)
        self.answerLabel.autoPinEdge(toSuperviewEdge: .leading)
        self.answerLabel.autoPinEdge(toSuperviewEdge: .trailing)
        self.answerLabel.autoPinEdge(toSuperviewEdge: .top, withInset: 0, relation: .greaterThanOrEqual)
        self.answerLabel.autoPinEdge(toSuperviewEdge: .bottom, withInset: 0, relation: .greaterThanOrEqual)
        self.answerLabel.autoAlignAxis(toSuperviewAxis: .horizontal)
        horizontalStackView.addArrangedSubview(answerContainerView)
        
        // button
        let buttonContainerView = UIView()
        buttonContainerView.addSubview(self.button)
        buttonContainerView.autoSetDimension(.width, toSize: Self.optionWidth)
        self.button.autoPinEdge(toSuperviewEdge: .leading)
        self.button.autoPinEdge(toSuperviewEdge: .trailing)
        self.button.autoPinEdge(toSuperviewEdge: .top, withInset: 0, relation: .greaterThanOrEqual)
        self.button.autoPinEdge(toSuperviewEdge: .bottom, withInset: 0, relation: .greaterThanOrEqual)
        self.button.autoAlignAxis(toSuperviewAxis: .horizontal)
        horizontalStackView.addArrangedSubview(buttonContainerView)
        
        self.contentView.addSubview(horizontalStackView)
        horizontalStackView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 0.0,
                                                                            left: Constants.Style.DefaultHorizontalMargins,
                                                                            bottom: 24.0,
                                                                            right: 0.0))
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Public Methods
    
    public func display(data: PossibleAnswer, isSelected: Bool, answerPressedCallback: @escaping PossibleAnswerCallback) {
        self.answerPressedCallback = answerPressedCallback
        self.answerLabel.attributedText = NSAttributedString.create(withText: data.text,
                                                                      fontStyle: .paragraph,
                                                                      colorType: .secondaryText,
                                                                      textAlignment: .left)
        if isSelected {
            self.button.setImage(ImagePalette.templateImage(withName: .radioButtonFilled), for: .normal)
            self.button.imageView?.tintColor = ColorPalette.color(withType: .secondary)
        } else {
            self.button.setImage(ImagePalette.templateImage(withName: .radioButtonOutline), for: .normal)
            self.button.imageView?.tintColor = ColorPalette.color(withType: .secondary).applyAlpha(0.5)
        }
    }
    
    // MARK: - Actions
    
    @objc private func buttonPressed() {
        self.answerPressedCallback?()
    }
}
