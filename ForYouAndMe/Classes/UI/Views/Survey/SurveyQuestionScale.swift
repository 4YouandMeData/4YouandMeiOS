//
//  SurveyQuestionScale.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 30/09/2020.
//

class SurveyQuestionScale: UIView {
    
    // Temporary workaround to avoid UILabels crowding
    private static let maxNumberOfLabels: Int = 20
    
    private var values: [Int] = []
    private var interval: Int = Constants.Survey.ScaleTypeDefaultInterval
    private var selectedValue: Int?
    private var surveyQuestion: SurveyQuestion
    private var slider: Slider = Slider()
    private var currentValue: UILabel = UILabel()
    private weak var delegate: SurveyQuestionProtocol?
    
    private var intervalStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.alignment = .fill
        stackView.distribution = .equalCentering
        stackView.axis = .horizontal
        return stackView
    }()
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    init(surveyQuestion: SurveyQuestion, delegate: SurveyQuestionProtocol) {
        guard let minimum = surveyQuestion.minimum,
              let maximum = surveyQuestion.maximum else {
            fatalError("Minimum, Maximum are required in Scale question")
        }
        let interval = surveyQuestion.interval ?? Constants.Survey.ScaleTypeDefaultInterval
        self.delegate = delegate
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
        
        self.autoSetDimension(.height, toSize: Constants.Style.SurveyPickerDefaultHeight)
        
        if let firstValue = self.values.first {
            self.selectedValue = firstValue
            self.delegate?.answerDidChange(self.surveyQuestion, answer: firstValue)
        }
    }
    
    // MARK: - Private Methods
    
    private func getScaleValues(minimumValue: Int,
                                maximumValue: Int,
                                interval: Int) -> [Int] {
        var scaleValues: [Int] = []
        var currentValue = minimumValue
        while maximumValue >= currentValue {
            scaleValues.append(currentValue)
            currentValue += interval
        }
        return scaleValues
    }
    
    private func configureScaleValues() {
        self.intervalStackView.subviews.forEach({ $0.removeFromSuperview()})
        if self.values.count < Self.maxNumberOfLabels {
            for value in self.values {
                self.intervalStackView.addLabel(withText: "\(Int(value))",
                                                fontStyle: .paragraph,
                                                color: ColorPalette.color(withType: .primaryText),
                                                horizontalInset: 1)
                
            }
        }
    }
    
    private func configureSlider(minimum: Int, maximum: Int, interval: Int) {
        self.interval = interval
        self.values = self.getScaleValues(minimumValue: minimum,
                                          maximumValue: maximum,
                                          interval: interval)
        // The slider ends on the last reachable step (e.g. 9 for 0-10 step 3), so the far right selects it.
        let lastValue = self.values.last ?? maximum
        self.slider.minimumValue = Float(minimum)
        self.slider.maximumValue = Float(lastValue)
        self.slider.value = Float(minimum)
        self.slider.accessibilityStep = Float(interval)
        self.slider.setup()
        self.configureScaleValues()
        
        // iOS 27 calls endTracking with a nil touch, so the value is read from UIControl events instead.
        // A release emits a final .valueChanged with isTracking == false; the touch-up events are a safety net.
        self.slider.addTarget(self, action: #selector(self.sliderValueChanged), for: .valueChanged)
        self.slider.addTarget(self, action: #selector(self.sliderValueChanged), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }
    
    /// Nearest allowed scale value (minimum + k * interval) to a raw slider value, clamped to the reachable range.
    static func snappedValue(_ rawValue: Float, minimum: Int, maximum: Int, interval: Int) -> Int {
        let lastStep = (maximum - minimum) / interval
        let step = Int(((rawValue - Float(minimum)) / Float(interval)).rounded())
        return minimum + min(max(step, 0), lastStep) * interval
    }
    
    @objc private func sliderValueChanged() {
        self.select(rawValue: self.slider.value, snapThumb: !self.slider.isTracking)
    }
    
    private func select(rawValue: Float, snapThumb: Bool) {
        guard let minimum = self.values.first, let maximum = self.values.last else { return }
        let value = Self.snappedValue(rawValue, minimum: minimum, maximum: maximum, interval: self.interval)
        if snapThumb {
            self.slider.setValue(Float(value), animated: true)
        }
        guard value != self.selectedValue else { return }
        self.selectedValue = value
        self.currentValue.text = "\(value)"
        self.delegate?.answerDidChange(self.surveyQuestion, answer: value)
    }
}
