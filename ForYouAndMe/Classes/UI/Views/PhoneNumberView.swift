//
//  PhoneNumberView.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 14/05/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import UIKit

class PhoneNumberView: GenericTextFieldView {
    
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
    
    init() {
        super.init(keyboardType: .phonePad) { text -> Bool in
            // TODO: Apply correct rule
            return text.count >= 5
        }
        
        self.horizontalStackView.insertArrangedSubview(self.countryCodeButton, at: 0)
        
        // TODO: Initialize with input values
        self.countryCodeButton.setTitle("+1", for: .normal)
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
        // TODO: Country Code button behaviour
        print("TODO: Country Code button behaviour")
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        // TODO: Format text based on country code
        print("TODO: Format text based on country code")
        return true
    }
}
