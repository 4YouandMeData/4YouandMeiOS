//
//  SurveyRangePicker.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 29/09/2020.
//

class SurveyRangePicker: UIView {
    
    private var surveyQuestion: SurveyQuestion
    private var currentValue: UILabel = UILabel()
    private var slider: Slider = Slider()
    private weak var delegate: SurveyQuestionProtocol?
    
    init(surveyQuestion: SurveyQuestion, delegate: SurveyQuestionProtocol) {
        
        guard let minimum = surveyQuestion.minimum, let maximum = surveyQuestion.maximum else {
            fatalError("Minimum and Maximum are required in Range question")
        }
        
        self.surveyQuestion = surveyQuestion
        self.delegate = delegate
        
        super.init(frame: .zero)
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        self.addSubview(stackView)
        stackView.autoPinEdgesToSuperviewSafeArea()
        
        stackView.addBlankSpace(space: 50)

        self.currentValue.text = "\(minimum)"
        self.currentValue.font = FontPalette.fontStyleData(forStyle: .title).font
        self.currentValue.textColor = ColorPalette.color(withType: .primaryText)
        self.currentValue.textAlignment = .center

        stackView.addArrangedSubview(self.currentValue)
        self.currentValue.setContentHuggingPriority(UILayoutPriority(251), for: .vertical)

        stackView.addBlankSpace(space: 40)
        
        self.slider.addTarget(self, action: #selector(self.changeValue(_:)), for: .valueChanged)
        self.slider.minimumValue = Float(minimum)
        self.slider.maximumValue = Float(maximum)
        self.slider.value = Float(minimum)
        self.slider.setup()
        stackView.addArrangedSubview(self.slider)
        
        stackView.addBlankSpace(space: 20)

        let sliderContainer = UIStackView()
        sliderContainer.axis = .horizontal
        stackView.addArrangedSubview(sliderContainer)
        
        sliderContainer.addLabel(text: surveyQuestion.minimumLabel ?? "\(minimum)",
                                 font: FontPalette.fontStyleData(forStyle: .header3).font,
                                 textColor: ColorPalette.color(withType: .primaryText),
                                 textAlignment: .left)
        
        sliderContainer.addLabel(text: surveyQuestion.maximumLabel ?? "\(maximum)",
                                 font: FontPalette.fontStyleData(forStyle: .header3).font,
                                 textColor: ColorPalette.color(withType: .primaryText),
                                 textAlignment: .right)
        sliderContainer.setContentHuggingPriority(UILayoutPriority(252), for: .vertical)
        
        let dummyView = UIView()
        stackView.addArrangedSubview(dummyView)
        dummyView.setContentHuggingPriority(UILayoutPriority(100), for: .vertical)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func changeValue(_ sender: UISlider) {
        
        let answer = Int(sender.value)
        self.currentValue.text = "\(answer)"
        self.delegate?.answerDidChange(self.surveyQuestion, answer: Int(sender.value))
    }
}
