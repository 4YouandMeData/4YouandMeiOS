//
//  PhoneNumberView.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 14/05/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import UIKit
import RxSwift

class PhoneNumberView: UIView {
    
    public var isValid: BehaviorSubject<Bool> = BehaviorSubject<Bool>(value: false)
    public var text: String { self.phoneNumberTextField.text ?? "" }
    
    private lazy var countryCodeButton: UIButton = {
        let button = UIButton()
        button.setTitleColor(ColorPalette.color(withType: .secondaryText), for: .normal)
        button.titleLabel?.font = FontPalette.font(withSize: 20.0)
        button.contentEdgeInsets = UIEdgeInsets.zero
        button.addTarget(self, action: #selector(self.countryCodeButtonPressed), for: .touchUpInside)
        button.setContentHuggingPriority(UILayoutPriority(1000), for: .horizontal)
        button.setContentCompressionResistancePriority(UILayoutPriority(1000), for: .horizontal)
        return button
    }()
    
    private lazy var phoneNumberTextField: UITextField = {
        let textField = UITextField()
        textField.textColor = ColorPalette.color(withType: .secondaryText)
        textField.tintColor = ColorPalette.color(withType: .secondaryText)
        textField.keyboardType = .phonePad
        textField.font = FontPalette.font(withSize: 20.0)
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
    
    private let disposeBag = DisposeBag()
    
    init() {
        super.init(frame: .zero)
        
        self.autoSetDimension(.height, toSize: 48.0)
        self.addHorizontalBorderLine(position: .bottom,
                                              leftMargin: 0,
                                              rightMargin: 0,
                                              color: ColorPalette.color(withType: .secondary).applyAlpha(0.2))
        
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 8.0
        stackView.addArrangedSubview(self.countryCodeButton)
        stackView.addArrangedSubview(self.phoneNumberTextField)
        let iconContainerView = UIView()
        iconContainerView.addSubview(self.textFieldEditButton)
        self.textFieldEditButton.autoPinEdgesToSuperviewEdges()
        iconContainerView.addSubview(self.textFieldCheckmarkButton)
        self.textFieldCheckmarkButton.autoPinEdgesToSuperviewEdges()
        iconContainerView.autoSetDimension(.width, toSize: 40.0)
        stackView.addArrangedSubview(iconContainerView)
        
        self.addSubview(stackView)
        stackView.autoPinEdgesToSuperviewEdges()
        
        // TODO: Initialize with input values
        self.countryCodeButton.setTitle("+1", for: .normal)
        
        self.isValid.subscribe(onNext: { [weak self] isValid in
            guard let self = self else { return }
            self.self.updateUI(phoneValid: isValid)
        }).disposed(by: self.disposeBag)
        
        self.checkValidation()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: Actions
    
    @objc private func countryCodeButtonPressed() {
        // TODO: Country Code button behaviour
        print("TODO: Country Code button behaviour")
    }
    
    @objc private func textFieldEditButtonPressed() {
        self.phoneNumberTextField.becomeFirstResponder()
    }
    
    @objc private func textFieldDidChange(_ textField: UITextField) {
        self.checkValidation()
    }
    
    // MARK: Private Methods
    
    private func updateUI(phoneValid: Bool) {
        self.textFieldCheckmarkButton.isHidden = false == phoneValid
        self.textFieldEditButton.isHidden = phoneValid
    }
    
    private func checkValidation() {
        // TODO: Apply correct rule
        let isValid = self.phoneNumberTextField.text?.count ?? 0 >= 5
        self.isValid.onNext(isValid)
    }
}

extension PhoneNumberView: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        UIView.animate(withDuration: 0.5, delay: 0.0, options: .curveEaseIn, animations: { [weak self] in
        guard let self = self else { return }
        self.textFieldEditButton.alpha = 1.0
        })
    }
    func textFieldDidEndEditing(_ textField: UITextField) {
        UIView.animate(withDuration: 0.5, delay: 0.0, options: .curveEaseIn, animations: { [weak self] in
        guard let self = self else { return }
        self.textFieldEditButton.alpha = 0.0
        })
    }
}
