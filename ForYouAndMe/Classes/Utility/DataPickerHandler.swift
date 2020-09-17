//
//  DataPickerHandler.swift
//  SeiToscana
//
//  Created by Leonardo Passeri on 17/01/2018.
//  Copyright © 2018 Balzo. All rights reserved.
//

import UIKit

protocol DataPickerItem: Equatable {
    var displayText: String { get }
}

@objc protocol DataPickerHandlerDelegate {
    @objc optional func dataPickerTextFieldShouldBeginEditing(_ textField: UITextField) -> Bool
    @objc optional func dataPickerTextFieldValueChanged(_ textField: UITextField)
    @objc optional func dataPickerTextFieldDoneButton(_ textField: UITextField)
}

class DataPickerHandler<T: DataPickerItem>: NSObject, UIPickerViewDelegate, UIPickerViewDataSource, UITextFieldDelegate {

    typealias DisplayLabelCallback = ((T) -> String)
    
    public weak var delegate: DataPickerHandlerDelegate?
    
    private var textField: UITextField
    private var pickerView: UIPickerView
    private var pickerData: [T] = []
    private var lastSelectedRow: Int = -1
    private var selectedRow: Int = -1
    
    public init(textField: UITextField, tintColor: UIColor? = nil) {
        
        self.textField = textField
        
        self.pickerView = UIPickerView(frame: CGRect(x: 0,
                                                     y: UIScreen.main.bounds.size.height - 216,
                                                     width: UIScreen.main.bounds.size.width,
                                                     height: 216))
        
        super.init()
        
        self.pickerView.backgroundColor = .white
        self.pickerView.delegate = self
        self.pickerView.dataSource = self
        self.textField.inputView = self.pickerView
        self.textField.delegate = self
        
        self.setupToolbar(tintColor: tintColor)
    }
    
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
    
    public func hasData() -> Bool {
        return !self.pickerData.isEmpty
    }
    
    public func getSelectedData() -> T? {
        var result: T?
        if 0 <= self.selectedRow && self.selectedRow < self.pickerData.count {
            result = self.pickerData[self.selectedRow]
        }
        return result
    }
    
    public func updateData(with pickerData: [T], initialValue: T?) {
        self.pickerData = pickerData
        
        self.pickerView.reloadAllComponents()
        
        self.clear()
        
        if let initialValue = initialValue, let initialValueIndex = pickerData.firstIndex(of: initialValue) {
            self.pickerView.selectRow(initialValueIndex, inComponent: 0, animated: false)
            self.lastSelectedRow = initialValueIndex
            self.selectedRow = initialValueIndex
            self.updateTextField()
        }
    }
    
    public func clear() {
        self.lastSelectedRow = -1
        self.selectedRow = -1
        if self.pickerData.count > 0 {
            self.pickerView.selectRow(0, inComponent: 0, animated: false)
        }
        self.updateTextField()
    }
    
    // MARK: Actions
    
    @objc func cancelPicker() {
        
        self.selectedRow = self.lastSelectedRow
        if self.pickerData.count > 0 {
            self.pickerView.selectRow(self.selectedRow, inComponent: 0, animated: false)
        }
        self.updateTextField()
        
        self.textField.resignFirstResponder()
    }
    
    @objc func donePicker() {
        self.textField.resignFirstResponder()
        self.delegate?.dataPickerTextFieldDoneButton?(self.textField)
    }
    
    // MARK: PickerView Data Source
    
    // returns the number of 'columns' to display.
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return self.pickerData.count
    }
    
    // MARK: PickerView Delegate
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return self.pickerData[row].displayText
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        self.selectedRow = row
        self.updateTextField()
    }
    
    // MARK: UITextField Delegate
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        if self.pickerData.count > 0 {
            self.selectedRow = self.pickerView.selectedRow(inComponent: 0)
            self.updateTextField()
        }
    }
    
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        return self.delegate?.dataPickerTextFieldShouldBeginEditing?(_:textField) ?? true
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    // This is to avoid editing, cut and paste while using a date picker
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        return false
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        self.lastSelectedRow = self.selectedRow
    }
    
    // MARK: Private
    
    private func updateTextField() {
        var newValue: String?
        if 0 <= self.selectedRow && self.selectedRow < self.pickerData.count {
            newValue = self.pickerData[self.selectedRow].displayText
        } else {
            newValue = nil
        }
        if newValue != self.textField.text {
            self.textField.text = newValue
            self.delegate?.dataPickerTextFieldValueChanged?(_:textField)
        }
    }
}
