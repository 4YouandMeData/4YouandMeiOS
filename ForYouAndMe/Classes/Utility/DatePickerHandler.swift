//
//  DatePickerHandler.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 17/09/2020.
//

import UIKit

@objc protocol DatePickerHandlerDelegate {
    @objc optional func datePickerTextFieldShouldBeginEditing(_ textField: UITextField) -> Bool
    @objc optional func datePickerTextFieldValueChanged(_ textField: UITextField)
    @objc optional func datePickerTextFieldDoneButton(_ textField: UITextField)
}

class DatePickerHandler: NSObject, UITextFieldDelegate {
    
    public weak var delegate: DatePickerHandlerDelegate?
    
    public var selectedDate: Date { self.pickerView.date }
    
    private let pickerView: UIDatePicker
    private let dateFormatter: DateFormatter
    private let textField: UITextField
    
    private var lastSelectedDate: Date?
    
    public init(textField: UITextField,
                tintColor: UIColor? = nil,
                dateFormatter: DateFormatter,
                datePickerMode: UIDatePicker.Mode) {
        
        self.textField = textField
        
        self.pickerView = UIDatePicker()
        self.dateFormatter = dateFormatter
        
        super.init()
        
        self.pickerView.backgroundColor = .white
        self.pickerView.datePickerMode = datePickerMode
        self.textField.inputView = self.pickerView
        self.textField.delegate = self
        self.textField.tintColor = .clear // Remove cursor
        
        self.pickerView.addTarget(self, action: #selector(self.dateDidChanged), for: .valueChanged)
        
        self.setupToolbar(tintColor: tintColor)
    }
    
    // MARK: - Public Methods
    
    public func update(withMinDate minDate: Date?, maxDate: Date?, initialDate: Date?) {
        self.pickerView.minimumDate = minDate
        self.pickerView.maximumDate = maxDate
        if let initialDate = initialDate {
            self.pickerView.date = initialDate
            self.lastSelectedDate = initialDate
        }
        self.updateTextField()
    }
    
    // MARK: - Private Methods
    
    private func setupToolbar(tintColor: UIColor? = nil) {
        
        let toolBar = UIToolbar()
        toolBar.barStyle = .default
        toolBar.isTranslucent = true
        if let tintColor = tintColor {
            toolBar.tintColor = tintColor
        }
        toolBar.sizeToFit()
        
        let cancelButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(self.cancelPicker))
        let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(self.donePicker))
        let spaceButton = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        
        toolBar.setItems([cancelButton, spaceButton, doneButton], animated: false)
        self.textField.inputAccessoryView = toolBar
    }
    
    private func updateTextField() {
        let dateText = self.dateFormatter.string(from: self.pickerView.date)
        if dateText != self.textField.text {
            self.textField.text = dateText
            self.delegate?.datePickerTextFieldValueChanged?(_: self.textField)
        }
    }
    
    // MARK: Actions
    
    @objc func dateDidChanged() {
        self.updateTextField()
    }
    
    @objc func cancelPicker() {
        if let lastSelectedDate = self.lastSelectedDate {
            self.pickerView.date = lastSelectedDate
        }
        self.textField.resignFirstResponder()
        self.updateTextField()
    }
    
    @objc func donePicker() {
        self.textField.resignFirstResponder()
        self.delegate?.datePickerTextFieldDoneButton?(self.textField)
        self.updateTextField()
    }
    
    // MARK: UITextField Delegate
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        self.updateTextField()
    }
    
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        return self.delegate?.datePickerTextFieldShouldBeginEditing?(_:textField) ?? true
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        self.lastSelectedDate = self.pickerView.date
        self.updateTextField()
    }
}
