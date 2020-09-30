//
//  SurveyRangePicker.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 29/09/2020.
//

class SurveyRangePicker: UIView {
    
    var surveyQuestion: SurveyQuestion
    var minimumLabel: UILabel = UILabel()
    var maximumLabel: UILabel = UILabel()
    var slider: Slider = Slider()
    
    init(surveyQuestion: SurveyQuestion) {
        
        guard let minimum = surveyQuestion.minimum, let maximum = surveyQuestion.maximum else {
            fatalError("Minimum and Maximum are required in Range question")
        }
        self.surveyQuestion = surveyQuestion
        self.minimumLabel.text = surveyQuestion.minimumLabel
        self.maximumLabel.text = surveyQuestion.maximumLabel
        
        super.init(frame: .zero)
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        self.addSubview(stackView)
        stackView.autoPinEdgesToSuperviewEdges()
        
        self.slider.addTarget(self, action: #selector(changeValue(_:)), for: .valueChanged)
        self.slider.value = Float(minimum)
        self.slider.minimumValue = Float(minimum)
        self.slider.maximumValue = Float(maximum)
        self.slider.setup()
        stackView.addArrangedSubview(self.slider)
        
        stackView.addBlankSpace(space: 30)
        stackView.addBlankSpace(space: 15)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func changeValue(_ sender: UISlider) {
//        sliderValueChanges?(Int(sender.value))
    }
}
