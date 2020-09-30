//
//  SurveyQuestionScale.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 30/09/2020.
//

class SurveyQuestionScale: UIView {
    
    private var values: [Int] = []
    private var surveyQuestion: SurveyQuestion
    private var slider: Slider = Slider()
    private var currentValue: UILabel = UILabel()
    
    private var intervalStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        return stackView
    }()
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    init(surveyQuestion: SurveyQuestion) {
        guard let minimum = surveyQuestion.minimum,
              let maximum = surveyQuestion.maximum,
              let interval = surveyQuestion.interval else {
            fatalError("Minimum, Maximum and interval are required in Scale question")
        }
        
        self.surveyQuestion = surveyQuestion
        super.init(frame: .zero)
        self.configureSlider(minimum: minimum, maximum: maximum, interval: interval)
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        self.addSubview(stackView)
        stackView.autoPinEdgesToSuperviewSafeArea()
        
        stackView.addBlankSpace(space: 60)
        
        self.currentValue.text = "\(minimum)"
        self.currentValue.font = FontPalette.fontStyleData(forStyle: .title).font
        self.currentValue.textColor = ColorPalette.color(withType: .primaryText)
        self.currentValue.textAlignment = .center

        stackView.addArrangedSubview(self.currentValue)
        self.currentValue.setContentHuggingPriority(UILayoutPriority(251), for: .vertical)

        stackView.addBlankSpace(space: 40)
                
        stackView.addArrangedSubview(self.slider)
        
        stackView.addBlankSpace(space: 20)

        stackView.addArrangedSubview(self.intervalStackView)
        
        let dummyView = UIView()
        stackView.addArrangedSubview(dummyView)
        dummyView.setContentHuggingPriority(UILayoutPriority(100), for: .vertical)
    }
    
    // MARK: - Private Methods
    
    private func getScaleValues(minmumValue: Int,
                                maximuValue: Int,
                                interval: Int) -> [Int] {
        var scaleValues = [minmumValue]
        var  value = minmumValue
        while maximuValue > value {
            value += interval
            scaleValues.append(value)
        }
        return scaleValues
    }
    
    private func configureScaleValues() {
        self.intervalStackView.subviews.forEach({ $0.removeFromSuperview()})
        for  value in self.values {
            
            self.intervalStackView.addLabel(withText: "\(Int(value))",
                                            fontStyle: .paragraph,
                                            color: ColorPalette.color(withType: .primaryText))
        }
    }
    
    private func configureSlider(minimum: Int, maximum: Int, interval: Int) {
        
//        self.slider.addTarget(self, action: #selector(changeValue(_:)), for: .valueChanged)
        self.slider.value = Float(minimum)
        self.slider.minimumValue = Float(minimum)
        self.slider.maximumValue = Float(maximum)
        self.slider.sliderType = .scale
        self.slider.setup()
        self.values = getScaleValues(minmumValue: minimum,
                                     maximuValue: maximum,
                                     interval: interval)
        self.configureScaleValues()
        
        self.slider.sliderPointTapped = {[weak self] pointTapped in
            self?.sliderTapped(pointTapped: pointTapped)
        }
    }
    
//    @objc private func changeValue(_ sender: UISlider) {
//        var new = sender.value
//        new.round()
//        new = (new <= 0) ? 1 : new
//        let value = Int(new)
//        guard value <= self.values.count, value > 0 else { return }
//        let actualValue = self.values[value - 1]
//        self.currentValue.text = "\(actualValue)"
//        self.slider.setValue(Float(actualValue), animated: false)
//    }
    
    fileprivate func sliderTapped(pointTapped: CGPoint) {
        var new = (CGFloat(values.count) * pointTapped.x) / slider.frame.width
        new.round()
        new = (new <= 0) ? 1 : new
        let value = Int(new)
        guard value <= self.values.count, value > 0 else { return }
        let actualValue = self.values[value - 1]
        self.currentValue.text = "\(actualValue)"
        self.slider.setValue(Float(actualValue), animated: true)
    }
}
