//
//  SurveyQuestionTextinput.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 29/09/2020.
//

class SurveyQuestionTextInput: UIView, GenericTextFieldViewDelegate {
    
    var surveyQuestion: SurveyQuestion
    var answer: String = String()
    
    fileprivate static let optionWidth: CGFloat = 74.0
    
    private lazy var scrollStackView: ScrollStackView = {
        let scrollStackView = ScrollStackView(axis: .vertical, horizontalInset: 0.0)
        scrollStackView.stackView.distribution = .fill
        return scrollStackView
    }()
        
    init(surveyQuestion: SurveyQuestion) {
        
        self.surveyQuestion = surveyQuestion
        super.init(frame: .zero)
        self.addSubview(self.scrollStackView)
        self.scrollStackView.autoPinEdgesToSuperviewEdges()
        
        self.scrollStackView.stackView.addBlankSpace(space: 40)
        
        let textFieldView = GenericTextFieldView(keyboardType: .default, styleCategory: .primary)
        textFieldView.delegate = self
        textFieldView.textField.placeholder = self.surveyQuestion.placeholder ?? ""
        self.scrollStackView.stackView.addArrangedSubview(textFieldView)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func genericTextFieldShouldReturn(textField: GenericTextFieldView) -> Bool {
        self.endEditing(true)
    }
}
