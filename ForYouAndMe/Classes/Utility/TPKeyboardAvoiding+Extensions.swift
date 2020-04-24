//
//  TPKeyboardAvoiding+Extensions.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 24/04/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import Foundation
import TPKeyboardAvoiding

public extension TPKeyboardAvoidingScrollView {
    
    // Call this to allow on textFieldShouldReturn to allow textFields with assigned delegate to move to the next
    // one, if the return key is pressed
    func onTextFieldShouldReturn(_ textField: UITextField) -> Bool {
        if !self.focusNextTextField() {
            textField.resignFirstResponder()
        }
        return true
    }
    
}
