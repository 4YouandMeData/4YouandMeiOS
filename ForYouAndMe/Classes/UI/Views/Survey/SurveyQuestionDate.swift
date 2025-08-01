//
//  SurveyQuestionDate.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 29/09/2020.
//

class SurveyQuestionDate: UIView {
    
    private var surveyQuestion: SurveyQuestion
    private weak var delegate: SurveyQuestionProtocol?
    
    init(surveyQuestion: SurveyQuestion, delegate: SurveyQuestionProtocol) {
        
        self.delegate = delegate
        self.surveyQuestion = surveyQuestion
        super.init(frame: .zero)
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        self.addSubview(stackView)
        stackView.autoPinEdgesToSuperviewEdges()
        
        stackView.addBlankSpace(space: 20)
        
        let datePicker = UIDatePicker()
        datePicker.minimumDate = surveyQuestion.minimumDate
        datePicker.maximumDate = surveyQuestion.maximumDate
        if #available(iOS 13.4, *) {
            datePicker.preferredDatePickerStyle = .wheels
        }
        datePicker.datePickerMode = .date
        datePicker.tintColor = ColorPalette.color(withType: .primary)
        datePicker.backgroundColor = .white
        datePicker.addTarget(self, action: #selector(self.handleDatePicker), for: .valueChanged)
        self.handleDatePicker(datePicker)
        stackView.addArrangedSubview(datePicker)
        stackView.addBlankSpace(space: 20)
        
        self.autoSetDimension(.height, toSize: Constants.Style.SurveyPickerDefaultHeight)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc func handleDatePicker(_ datePicker: UIDatePicker) {
        print("\(datePicker.date)")
        self.delegate?.answerDidChange(self.surveyQuestion, answer: datePicker.date.string(withFormat: dateFormat))
    }
}
