//
//  QuestionBooleanTableViewCell.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 22/05/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import UIKit

struct QuestionBooleanDisplayData {
    let identifier: String
    let question: String
    let answerA: String
    let answerB: String
    let correctAnswerA: Bool?
    var answerAisActive: Bool?
}

class QuestionBooleanTableViewCell: UITableViewCell {
    
    typealias QuestionBooleanAnswerCallback = ((Bool) -> Void)
    
    fileprivate static let optionWidth: CGFloat = 50.0
    
    private lazy var questionLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        return label
    }()
    
    private lazy var answerAButton: UIButton = {
        let button = UIButton()
        button.contentEdgeInsets = UIEdgeInsets(top: 8.0, left: 8.0, bottom: 8.0, right: 8.0)
        button.addTarget(self, action: #selector(self.answerAButtonPressed), for: .touchUpInside)
        return button
    }()
    
    private lazy var answerBButton: UIButton = {
        let button = UIButton()
        button.contentEdgeInsets = UIEdgeInsets(top: 8.0, left: 8.0, bottom: 8.0, right: 8.0)
        button.addTarget(self, action: #selector(self.answerBButtonPressed), for: .touchUpInside)
        return button
    }()
    
    private var questionIdentifier: String = ""
    private var answerPressedCallback: QuestionBooleanAnswerCallback?
    
    private let answerALabel: UILabel = UILabel()
    private let answerBLabel: UILabel = UILabel()
    
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
        
        let questionContainerView = UIView()
        questionContainerView.addSubview(self.questionLabel)
        self.questionLabel.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .bottom)
        self.questionLabel.autoPinEdge(toSuperviewEdge: .bottom, withInset: 0, relation: .greaterThanOrEqual)
        
        horizontalStackView.addArrangedSubview(questionContainerView)
        
        horizontalStackView.addOption(button: self.answerAButton, label: self.answerALabel)
        horizontalStackView.addOption(button: self.answerBButton, label: self.answerBLabel)
        
        self.contentView.addSubview(horizontalStackView)
        horizontalStackView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 32.0,
                                                                            left: Constants.Style.DefaultHorizontalMargins,
                                                                            bottom: 32.0,
                                                                            right: Constants.Style.DefaultHorizontalMargins))
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Public Methods
    
    public func display(data: QuestionBooleanDisplayData, answerPressedCallback: @escaping QuestionBooleanAnswerCallback) {
        self.questionIdentifier = data.identifier
        self.answerPressedCallback = answerPressedCallback
        self.questionLabel.attributedText = NSAttributedString.create(withText: data.question,
                                                                      fontStyle: .paragraph,
                                                                      colorType: .primaryText,
                                                                      textAlignment: .left)
        self.answerALabel.attributedText = NSAttributedString.create(withText: data.answerA,
                                                                     fontStyle: .paragraph,
                                                                     colorType: .fourthText)
        self.answerBLabel.attributedText = NSAttributedString.create(withText: data.answerB,
                                                                     fontStyle: .paragraph,
                                                                     colorType: .fourthText)
        self.setButton(self.answerAButton, active: false)
        self.setButton(self.answerBButton, active: false)
        if let answerAisActive = data.answerAisActive {
            if answerAisActive {
                self.setButton(self.answerAButton, active: true)
            } else {
                self.setButton(self.answerBButton, active: true)
            }
        }
    }
    
    // MARK: - Actions
    
    @objc private func answerAButtonPressed() {
        self.answerPressedCallback?(true)
    }
    
    @objc private func answerBButtonPressed() {
        self.answerPressedCallback?(false)
    }
    
    // MARK: - Private Methods
    
    private func setButton(_ button: UIButton, active: Bool) {
        if active {
            button.setImage(ImagePalette.templateImage(withName: .radioButtonFilled), for: .normal)
            button.imageView?.tintColor = ColorPalette.color(withType: .active)
        } else {
            button.setImage(ImagePalette.templateImage(withName: .radioButtonOutline), for: .normal)
            button.imageView?.tintColor = ColorPalette.color(withType: .inactive)
        }
    }
}

// MARK: - Extension (UIStackView)

fileprivate extension UIStackView {
    func addOption(button: UIButton, label: UILabel) {
        let containerView = UIView()
        containerView.autoSetDimension(.width, toSize: QuestionBooleanTableViewCell.optionWidth)
        
        let verticalStackView = UIStackView()
        verticalStackView.axis = .vertical
        
        containerView.addSubview(verticalStackView)
        // Note: -12.0 is a graphically found value to ensure alignment of the radio buttons upper bound with the question label.
        // This negative inset is needed to compensate space from the button to its container and button contenst insets.
        verticalStackView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: -12.0, left: 0.0, bottom: 0.0, right: 0.0),
                                                       excludingEdge: .bottom)
        verticalStackView.autoPinEdge(toSuperviewEdge: .bottom, withInset: 0, relation: .greaterThanOrEqual)
        
        let buttonContainerButton = UIView()
        buttonContainerButton.autoSetDimensions(to: CGSize(width: QuestionBooleanTableViewCell.optionWidth,
                                                           height: QuestionBooleanTableViewCell.optionWidth))
        buttonContainerButton.addSubview(button)
        button.autoCenterInSuperview()
        
        verticalStackView.addArrangedSubview(buttonContainerButton)
        verticalStackView.addArrangedSubview(label)
        
        self.addArrangedSubview(containerView)
    }
}
