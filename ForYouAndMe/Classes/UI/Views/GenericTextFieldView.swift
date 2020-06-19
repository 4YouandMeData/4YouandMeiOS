//
//  GenericTextFieldView.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 14/05/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import Foundation
import RxSwift
import RxCocoa

class GenericTextFieldView: UIView {
    
    typealias GenericTextFieldViewValidation = ((String) -> Bool)
    
    static var normalTextColor: UIColor { ColorPalette.color(withType: .secondaryText) }
    static var errorColor: UIColor { ColorPalette.color(withType: .primaryText) }
    
    public var validationCallback: GenericTextFieldViewValidation?
    public var maxCharacters: Int?
    
    public var isValid: BehaviorRelay<Bool> = BehaviorRelay<Bool>(value: false)
    public var text: String {
        get { self.textField.text ?? "" }
        set {
            self.textField.text = newValue
            self.checkValidation()
        }
    }
    
    public lazy var horizontalStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 8.0
        stackView.addArrangedSubview(self.textField)
        return stackView
    }()
    
    public lazy var textField: UITextField = {
        let textField = UITextField()
        textField.textColor = Self.normalTextColor
        textField.tintColor = Self.normalTextColor
        textField.keyboardType = .phonePad
        textField.font = FontPalette.fontStyleData(forStyle: .paragraph).font
        textField.delegate = self
        textField.addTarget(self, action: #selector(self.textFieldDidChange(_:)), for: .editingChanged)
        return textField
    }()
    
    private lazy var textFieldEditButton: UIButton = {
        let button = UIButton()
        button.imageView?.contentMode = .scaleAspectFit
        button.setImage(ImagePalette.image(withName: .edit), for: .normal)
        button.addTarget(self, action: #selector(self.textFieldEditButtonPressed), for: .touchUpInside)
        return button
    }()
    
    private lazy var textFieldCheckmarkButton: UIButton = {
        let button = UIButton()
        button.imageView?.contentMode = .scaleAspectFit
        button.setImage(ImagePalette.image(withName: .checkmark), for: .normal)
        button.addTarget(self, action: #selector(self.textFieldEditButtonPressed), for: .touchUpInside)
        return button
    }()
    
    private lazy var errorLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.autoSetDimension(.height, toSize: 36, relation: .greaterThanOrEqual)
        return label
    }()
    
    private let disposeBag = DisposeBag()
    
    init(keyboardType: UIKeyboardType) {
        super.init(frame: .zero)
        
        let iconContainerView = UIView()
        iconContainerView.addSubview(self.textFieldEditButton)
        self.textFieldEditButton.autoPinEdgesToSuperviewEdges()
        iconContainerView.addSubview(self.textFieldCheckmarkButton)
        self.textFieldCheckmarkButton.autoPinEdgesToSuperviewEdges()
        iconContainerView.autoSetDimension(.width, toSize: 40.0)
        self.horizontalStackView.addArrangedSubview(iconContainerView)
        
        let textFieldContainerView = UIView()
        textFieldContainerView.autoSetDimension(.height, toSize: 48.0)
        textFieldContainerView.addHorizontalBorderLine(position: .bottom,
                                              leftMargin: 0,
                                              rightMargin: 0,
                                              color: ColorPalette.color(withType: .secondary).applyAlpha(0.2))
        textFieldContainerView.addSubview(self.horizontalStackView)
        self.horizontalStackView.autoPinEdgesToSuperviewEdges()
        
        let verticalStackView = UIStackView()
        verticalStackView.axis = .vertical
        verticalStackView.spacing = 16.0
        verticalStackView.addArrangedSubview(textFieldContainerView)
        verticalStackView.addArrangedSubview(self.errorLabel)
        
        self.addSubview(verticalStackView)
        verticalStackView.autoPinEdgesToSuperviewEdges()
        
        self.textField.keyboardType = keyboardType
        
        self.isValid.subscribe(onNext: { [weak self] isValid in
            guard let self = self else { return }
            self.self.updateUI(phoneValid: isValid)
        }).disposed(by: self.disposeBag)
        
        self.clearError(clearErrorText: true)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: Public Methods
    
    public func setError(errorText: String) {
        self.errorLabel.attributedText = NSAttributedString.create(withText: errorText,
                                                                   fontStyle: .header3,
                                                                   color: Self.errorColor,
                                                                   textAlignment: .left)
        self.textField.textColor = Self.errorColor
        self.textField.tintColor = Self.errorColor
    }
    
    public func clearError(clearErrorText: Bool) {
        if clearErrorText {
            self.errorLabel.text = ""
        }
        self.textField.textColor = Self.normalTextColor
        self.textField.tintColor = Self.normalTextColor
    }
    
    public func checkValidation() {
        let isValid = self.validationCallback?(self.textField.text ?? "") ?? false
        self.isValid.accept(isValid)
    }
    
    // MARK: Actions
    
    @objc private func textFieldEditButtonPressed() {
        self.textField.becomeFirstResponder()
    }
    
    @objc func textFieldDidChange(_ textField: UITextField) {
        self.clearError(clearErrorText: false)
        self.checkValidation()
    }
    
    // MARK: Private Methods
    
    private func updateUI(phoneValid: Bool) {
        self.textFieldCheckmarkButton.isHidden = false == phoneValid
        self.textFieldEditButton.isHidden = phoneValid
    }
}

extension GenericTextFieldView: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        UIView.animate(withDuration: 0.2, delay: 0.0, options: .curveEaseIn, animations: { [weak self] in
        guard let self = self else { return }
        self.textFieldEditButton.alpha = 0.0
        })
    }
    func textFieldDidEndEditing(_ textField: UITextField) {
        UIView.animate(withDuration: 0.2, delay: 0.0, options: .curveEaseIn, animations: { [weak self] in
        guard let self = self else { return }
        self.textFieldEditButton.alpha = 1.0
        })
    }
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let newString = textField.getNewString(forRange: range, replacementString: string)
        if let maxCharacters = self.maxCharacters, newString.count > maxCharacters {
            return false
        } else {
            return true
        }
    }
}

extension UITextField {
    func getNewString(forRange range: NSRange, replacementString string: String) -> String {
        let currentString = self.text as NSString?
        return currentString?.replacingCharacters(in: range, with: string) ?? ""
    }
}
