//
//  PhoneNumberView.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 14/05/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import UIKit
import PhoneNumberKit

class PhoneNumberView: GenericTextFieldView {
    
    private static let maxDigits: Int = 20
    
    private let phoneNumberKit = PhoneNumberKit()
    
    public var fullNumber: String {
        let fullNumberFormatted = self.getCountryCodeNumber() + " " + self.text
        guard let phoneNumber = try? self.phoneNumberKit.parse(fullNumberFormatted, withRegion: self.countryCode) else {
            assertionFailure("Couldn't parse current phone number")
            return fullNumberFormatted
        }
        return self.phoneNumberKit.format(phoneNumber, toType: .e164)
    }
    
    public var countryCode: String = "US" {
        didSet {
            self.updateCountryCode()
            self.checkValidation()
        }
    }
    
    private lazy var countryCodeButton: UIButton = {
        let button = UIButton()
        button.setTitleColor(Self.normalTextColor, for: .normal)
        button.titleLabel?.font = FontPalette.font(withSize: 20.0)
        button.contentEdgeInsets = UIEdgeInsets.zero
        button.addTarget(self, action: #selector(self.countryCodeButtonPressed), for: .touchUpInside)
        button.setContentHuggingPriority(UILayoutPriority(1000), for: .horizontal)
        button.setContentCompressionResistancePriority(UILayoutPriority(1000), for: .horizontal)
        return button
    }()
    
    private weak var presenter: UIViewController?
    
    init(presenter: UIViewController) {
        self.presenter = presenter
        super.init(keyboardType: .phonePad)
        self.validationCallback = { [weak self] text -> Bool in
            guard let self = self else { return false }
            return self.phoneNumberKit.isValidPhoneNumber(self.getCountryCodeNumber() + text,
                                                          withRegion: self.countryCode,
                                                          ignoreType: false)
        }
        self.horizontalStackView.insertArrangedSubview(self.countryCodeButton, at: 0)
        
        self.updateCountryCode()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: Public Methods
    
    public override func setError(errorText: String) {
        super.setError(errorText: errorText)
        self.countryCodeButton.setTitleColor(Self.errorColor, for: .normal)
    }
    
    public override func clearError(clearErrorText: Bool) {
        super.clearError(clearErrorText: clearErrorText)
        self.countryCodeButton.setTitleColor(Self.normalTextColor, for: .normal)
    }
    
    // MARK: Actions
    
    @objc private func countryCodeButtonPressed() {
        guard let presenter = self.presenter else { return }
        let pickerViewController = CountryCodePickerViewController(phoneNumberKit: self.phoneNumberKit)
        let nav = UINavigationController(rootViewController: pickerViewController)
        presenter.present(nav, animated: true)
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        
        guard let currentString: NSString = textField.text as NSString?,
            let validationRule = self.validationCallback,
            string.rangeOfCharacter(from: CharacterSet.letters) == nil else { return false }
        let newString: NSString = currentString.replacingCharacters(in: range, with: string) as NSString
        
        if newString.length > currentString.length, newString.length >= Self.maxDigits {
            // Prevent adding characters over maximum digits
            return false
        } else if validationRule(currentString as String) == true,
            validationRule(newString as String) == false,
            newString.length > currentString.length {
            // Prevent adding characters on an already valid phone number if the new one is not valid
            return false
        } else {
            return true
        }
    }
    
    override func textFieldDidChange(_ textField: UITextField) {
        let partialFormatter = PartialFormatter(phoneNumberKit: self.phoneNumberKit,
                                                defaultRegion: self.countryCode,
                                                withPrefix: false,
                                                maxDigits: Self.maxDigits)
        self.text = partialFormatter.formatPartial(self.text)
        super.textFieldDidChange(textField)
    }
    
    // MARK: Private Methods
    
    private func updateCountryCode() {
        guard let countryCode = self.phoneNumberKit.countryCode(for: self.countryCode) else {
            assertionFailure("Cannot find give country")
            self.setError(errorText: "Cannot Convert country code")
            return
        }
        self.countryCodeButton.setTitle("+\(countryCode)", for: .normal)
    }
    
    private func getCountryCodeNumber() -> String {
        guard let countryCode = self.phoneNumberKit.countryCode(for: self.countryCode) else {
            assertionFailure("Cannot find give country")
            self.setError(errorText: "Cannot Convert country code")
            return ""
        }
        return "+\(countryCode)"
    }
}
