//
//  PhoneNumberView.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 14/05/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import UIKit
import PhoneNumberKit
import CountryPickerView

class PhoneNumberView: GenericTextFieldView {
    
    private static let maxDigits: Int = 20
    
    public var fullNumber: String {
        let fullNumberFormatted = self.getCountryCodeNumber() + " " + self.text
        guard let phoneNumber = try? self.phoneNumberKit.parse(fullNumberFormatted, withRegion: self.countryCode) else {
            assertionFailure("Couldn't parse current phone number")
            return fullNumberFormatted
        }
        return self.phoneNumberKit.format(phoneNumber, toType: .e164)
    }
    
    public var countryCode: String = PhoneNumberKit.defaultRegionCode() {
        didSet {
            self.updateUI()
        }
    }
    
    private lazy var countryCodeButton: UIButton = {
        let button = UIButton()
        button.setTitleColor(Self.normalTextColor, for: .normal)
        button.titleLabel?.font = FontPalette.fontStyleData(forStyle: .paragraph).font
        button.contentEdgeInsets = UIEdgeInsets.zero
        button.addTarget(self, action: #selector(self.countryCodeButtonPressed), for: .touchUpInside)
        button.setContentHuggingPriority(UILayoutPriority(1000), for: .horizontal)
        button.setContentCompressionResistancePriority(UILayoutPriority(1000), for: .horizontal)
        return button
    }()
    
    private lazy var countryPickerView: CountryPickerView = {
        let view = CountryPickerView()
        view.dataSource = self
        view.delegate = self
        return view
    }()
    
    private weak var presenter: UIViewController?
    
    private let allowedCountryCodes: [String]
    private let phoneNumberKit = PhoneNumberKit()
    
    init(presenter: UIViewController, allowedCountryCodes: [String]) {
        self.presenter = presenter
        self.allowedCountryCodes = allowedCountryCodes
        super.init(keyboardType: .phonePad)
        self.validationCallback = { [weak self] text -> Bool in
            guard let self = self else { return false }
            return self.validateText(text, ignoreType: false)
        }
        self.maxCharacters = Self.maxDigits
        self.horizontalStackView.insertArrangedSubview(self.countryCodeButton, at: 0)
        
        self.updateUI()
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
        self.countryPickerView.showCountriesList(from: presenter)
    }
    
    // MARK: Overridden Methods
    
    override func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard super.textField(textField, shouldChangeCharactersIn: range, replacementString: string) else {
            return false
        }
        let currentString = textField.text ?? ""
        let newString = textField.getNewString(forRange: range, replacementString: string)
        
        if self.validateText(currentString, ignoreType: true) == true,
            self.validateText(newString, ignoreType: true) == false,
            newString.count > currentString.count {
            // Prevent adding characters on an already valid phone number if the new one is not valid
            return false
        } else {
            return true
        }
    }
    
    override func textFieldDidChange(_ textField: UITextField) {
        self.updateTextFormat()
        super.textFieldDidChange(self.textField)
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
    
    private func updateTextFormat() {
        let partialFormatter = PartialFormatter(phoneNumberKit: self.phoneNumberKit,
                                                defaultRegion: self.countryCode,
                                                withPrefix: false,
                                                maxDigits: Self.maxDigits)
        let previousText = self.text.filter("0123456789".contains)
        let nextText = partialFormatter.formatPartial(previousText)
        self.text = nextText
    }
    
    private func updateUI() {
        self.updateCountryCode()
        self.updateTextFormat()
        self.checkValidation()
    }
    
    private func validateText(_ text: String, ignoreType: Bool) -> Bool {
        return self.phoneNumberKit.isValidPhoneNumber(self.getCountryCodeNumber() + text,
                                                             withRegion: self.countryCode,
                                                             ignoreType: ignoreType)
    }
}

extension PhoneNumberView: CountryPickerViewDelegate {
    func countryPickerView(_ countryPickerView: CountryPickerView, didSelectCountry country: Country) {
        self.countryCode = country.code
    }
}

extension PhoneNumberView: CountryPickerViewDataSource {
    /// An array of countries you wish to show at the top of the list.
    /// This is useful if your app is targeted towards people in specific countries.
    /// - requires: The title for the section to be returned in `sectionTitleForPreferredCountries`
    func preferredCountries(in countryPickerView: CountryPickerView) -> [Country] {
        return self.allowedCountryCodes.compactMap { countryPickerView.getCountryByCode($0) }
    }
    
    /// The desired title for the preferred section.
    /// - **See:** `preferredCountries` method. Both are required for the section to be shown.
    func sectionTitleForPreferredCountries(in countryPickerView: CountryPickerView) -> String? {
        return ""
    }
    
    /// Determines if only the preferred section is shown
    func showOnlyPreferredSection(in countryPickerView: CountryPickerView) -> Bool {
        return true
    }
    
    /// The desired font for the section title labels on the list. Can be used to configure the text size.
    /// Default value is UIFont.boldSystemFont(ofSize: 17)
    func sectionTitleLabelFont(in countryPickerView: CountryPickerView) -> UIFont {
        return FontPalette.fontStyleData(forStyle: .header2).font
    }
    
    /// The desired font for the cell labels on the list. Can be used to configure the text size.
    /// Default value is UIFont.systemFont(ofSize: 17)
    func cellLabelFont(in countryPickerView: CountryPickerView) -> UIFont {
        return FontPalette.fontStyleData(forStyle: .paragraph).font
    }
    
    /// The navigation item title when the internal view controller is pushed/presented.
    func navigationTitle(in countryPickerView: CountryPickerView) -> String? {
        return StringsProvider.string(forKey: .phoneVerificationCountryPickerTitle)
    }
    
    /// A navigation item button to be used if the internal view controller is presented(not pushed).
    /// Return `nil` to use a default "Close" button.
    func closeButtonNavigationItem(in countryPickerView: CountryPickerView) -> UIBarButtonItem? {
        return UIBarButtonItem(image: ImagePalette.image(withName: .closeButton), style: .plain, target: nil, action: nil)
    }
    
    /// Determines if a country's phone code is shown alongside the country's name on the list.
    /// e.g Nigeria (+234)
    func showPhoneCodeInList(in countryPickerView: CountryPickerView) -> Bool {
        return true
    }
    
    /// Determines if a country's code is shown alongside the country's name on the list.
    /// e.g Nigeria (NG)
    func showCountryCodeInList(in countryPickerView: CountryPickerView) -> Bool {
        return true
    }
    
    /// Determines if the selected country is checked on the list.
    func showCheckmarkInList(in countryPickerView: CountryPickerView) -> Bool {
        return true
    }
}
