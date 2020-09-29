//
//  SurveyQuestionDate.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 29/09/2020.
//

class SurveyQuestionDate: UIView {
    
    var surveyQuestion: SurveyQuestion
    var minDate: Date
    var maxDate: Date
    
    init(surveyQuestion: SurveyQuestion) {
        self.surveyQuestion = surveyQuestion
        
        guard let minDate = self.surveyQuestion.minimumDate, let maxDate = self.surveyQuestion.maximumDate else {
            fatalError("Date requested min and max date")
        }
        self.minDate = minDate
        self.maxDate = maxDate
        super.init(frame: .zero)
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        self.addSubview(stackView)
        stackView.autoPinEdgesToSuperviewEdges()
        
        stackView.addBlankSpace(space: 20)
        
        let datePicker = UIDatePicker()
        datePicker.minimumDate = self.minDate
        datePicker.maximumDate = self.maxDate
        if #available(iOS 13.4, *) {
            datePicker.preferredDatePickerStyle = .wheels
        }
        datePicker.datePickerMode = .date
        datePicker.tintColor = ColorPalette.color(withType: .primary)
        datePicker.backgroundColor = .white
        datePicker.addTarget(self, action: #selector(self.handleDatePicker), for: .valueChanged)
        stackView.addArrangedSubview(datePicker)
        stackView.addBlankSpace(space: 20)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc func handleDatePicker(_ datePicker: UIDatePicker) {
        print("\(datePicker.date)")
    }
}
