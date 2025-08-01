//
//  SurveyQuestionNumerical.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 27/09/2020.
//

class SurveyQuestionNumerical: UIView, UIPickerViewDelegate, UIPickerViewDataSource {
    
    var surveyQuestion: SurveyQuestion
    
    private let numberOfItems: Int
    private let minumum: Int
    private let maximum: Int
    private var items: [String] = [String]()
    private weak var delegate: SurveyQuestionProtocol?
    
    init(surveyQuestion: SurveyQuestion, delegate: SurveyQuestionProtocol) {
        self.surveyQuestion = surveyQuestion
        
        guard let minimum = self.surveyQuestion.minimum, let maximum = self.surveyQuestion.maximum else {
            fatalError("Minimum and Maximum are required in numerical question")
        }
        
        self.delegate = delegate
        self.surveyQuestion = surveyQuestion
        self.minumum = Int(minimum)
        self.maximum = Int(maximum)
        self.numberOfItems = self.maximum - self.minumum
        super.init(frame: .zero)
        
        self.calculateRange()

        let pickerView = UIPickerView()
        pickerView.delegate = self
        pickerView.dataSource = self
        pickerView.backgroundColor = .clear
        
        self.addSubview(pickerView)
        pickerView.autoPinEdgesToSuperviewEdges()
        pickerView.selectRow(0, inComponent: 0, animated: false)
        self.pickerView(pickerView, didSelectRow: 0, inComponent: 0)
        
        self.autoSetDimension(.height, toSize: Constants.Style.SurveyPickerDefaultHeight)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func calculateRange() {
        for idx in 0...self.numberOfItems {
            self.items.append("\(self.minumum + idx)")
        }
        if let minimum = self.surveyQuestion.minimumDisplay, false == minimum.isEmpty {
            self.items.insert(minimum, at: 0)
        }
        
        if let maximum = self.surveyQuestion.maximumDisplay, false == maximum.isEmpty {
            self.items.insert(maximum, at: self.items.count)
        }
    }
    
    // MARK: Picker Datasource
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return self.items.count
    }
    
    // MARK: Picker Delegate
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return self.items[row]
    }
    
    func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
        return 51.0
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        
        let selectedItem = self.items[row]
        if selectedItem == self.surveyQuestion.minimumDisplay {
            self.delegate?.answerDidChange(self.surveyQuestion, answer: Constants.Survey.NumericTypeMinValue)
        } else if selectedItem == self.surveyQuestion.maximumDisplay {
            self.delegate?.answerDidChange(self.surveyQuestion, answer: Constants.Survey.NumericTypeMaxValue)
        } else {
            self.delegate?.answerDidChange(self.surveyQuestion, answer: selectedItem)
        }
    }
}
