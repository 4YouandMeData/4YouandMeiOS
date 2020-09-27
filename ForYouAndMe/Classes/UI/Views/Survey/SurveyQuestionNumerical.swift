//
//  SurveyQuestionNumerical.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 27/09/2020.
//

class SurveyQuestionNumerical: UIView, SurveyQuestionProtocol, UIPickerViewDelegate, UIPickerViewDataSource {
    
    var surveyQuestion: SurveyQuestion
    
    private let numberOfItems: Int
    private let minumum: Int
    private let maximum: Int
    private var items: [String] = [String]()
    
    init(surveyQuestion: SurveyQuestion) {
        self.surveyQuestion = surveyQuestion
        
        guard let minimum = self.surveyQuestion.minimum, let maximum = self.surveyQuestion.maximum else {
            fatalError("Minimum and Maximum are required in numerical question")
        }
        self.minumum = Int(minimum)
        self.maximum = Int(maximum)
        self.numberOfItems = self.maximum - self.minumum + 1
        super.init(frame: .zero)
        
        self.calculateRange()

        let pickerView = UIPickerView()
        pickerView.delegate = self
        pickerView.dataSource = self
        pickerView.clipsToBounds = true
        pickerView.tintColor = ColorPalette.color(withType: .primary)
        
        self.addSubview(pickerView)
        pickerView.autoPinEdgesToSuperviewEdges()
        pickerView.selectRow(Int(self.numberOfItems/2), inComponent: 0, animated: false)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func calculateRange() {
        for idx in 0...self.numberOfItems {
            self.items.append("\(self.minumum + idx)")
        }
    }
    
    // MARK: Picker Datasource
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
       return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return self.numberOfItems
    }
    
    // MARK: Picker Delegate
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return self.items[row]
    }
    
    func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
        return 51.0
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        pickerView.reloadAllComponents()
    }
    
    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {

        let label = UILabel()
        label.layer.masksToBounds = true
        label.layer.cornerRadius = 10
        label.text = self.items[row]
        label.textAlignment = NSTextAlignment.center
        label.font = FontPalette.fontStyleData(forStyle: .header2).font

        if pickerView.selectedRow(inComponent: component) == row {
            label.textColor = ColorPalette.color(withType: .secondaryText)
            label.layer.backgroundColor = ColorPalette.color(withType: .primary).cgColor
        } else {
            label.textColor = ColorPalette.color(withType: .primaryText)
            label.layer.backgroundColor = ColorPalette.color(withType: .secondary).cgColor
        }
        
        return label
    }
}
