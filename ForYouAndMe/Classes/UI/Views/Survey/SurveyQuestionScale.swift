//
//  SurveyQuestionScale.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 30/09/2020.
//

class SurveyQuestionScale: UIView {
    
    // Temporary workaround to avoid UILabels crowding
    private static let maxNumberOfLabels: Int = 20
    // Target gap between adjacent numbers: closer ones get a uniformly smaller font, down to the minimum scale.
    // Checked on unrounded widths, so pixel rounding of the labels can leave the real gap up to ~0.5pt smaller.
    private static let valueLabelMinimumGap: CGFloat = 4
    private static let valueLabelMinimumFontScale: CGFloat = 0.5
    
    private var values: [Int] = []
    private var interval: Int = Constants.Survey.ScaleTypeDefaultInterval
    private var selectedValue: Int?
    private var surveyQuestion: SurveyQuestion
    private var slider: Slider = Slider()
    private var currentValue: UILabel = UILabel()
    private weak var delegate: SurveyQuestionProtocol?
    
    // Numbers under the slider, positioned in layoutSubviews under the thumb position of their value.
    private let valueLabelsView = UIView()
    // Read once, like the row height derived from it, so a later Dynamic Type change cannot outgrow the row.
    private let valueLabelFont = FontPalette.fontStyleData(forStyle: .paragraph).font
    private var valueLabels: [UILabel] = []
    
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

        stackView.addArrangedSubview(self.valueLabelsView)
        let labelsHeight = self.valueLabels.isEmpty ? 0 : ceil(self.valueLabelFont.lineHeight)
        self.valueLabelsView.autoSetDimension(.height, toSize: labelsHeight)
        
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
        self.valueLabels.forEach { $0.removeFromSuperview() }
        self.valueLabels = []
        guard self.values.count < Self.maxNumberOfLabels else { return }
        self.valueLabels = self.values.map { value in
            let label = UILabel()
            label.text = "\(value)"
            label.font = self.valueLabelFont
            label.textColor = ColorPalette.color(withType: .primaryText)
            self.valueLabelsView.addSubview(label)
            return label
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        self.layoutValueLabels()
    }
    
    /// Centres each number under the thumb position of its value, so the numbers line up with the slider stops.
    private func layoutValueLabels() {
        guard !self.valueLabels.isEmpty else { return }
        // The inner stack view sets the slider and labels row frames in its own layout pass, which runs after this one.
        self.valueLabelsView.superview?.layoutIfNeeded()
        let trackRect = self.slider.trackRect(forBounds: self.slider.bounds)
        let centers = self.values.map { value -> CGFloat in
            let thumbRect = self.slider.thumbRect(forBounds: self.slider.bounds, trackRect: trackRect, value: Float(value))
            return self.slider.convert(thumbRect, to: self.valueLabelsView).midX
        }
        let sliderSpan = self.slider.convert(self.slider.bounds, to: self.valueLabelsView)
        let font = self.valueLabelFont
        let widths = self.valueLabels.map { ($0.text ?? "").size(withAttributes: [.font: font]).width }
        let scale = Self.valueLabelFontScale(centers: centers, widths: widths, minX: sliderSpan.minX, maxX: sliderSpan.maxX)
        let pixel = 1 / max(self.traitCollection.displayScale, 1)
        for (label, center) in zip(self.valueLabels, centers) {
            label.font = font.withSize(font.pointSize * scale)
            let size = label.intrinsicContentSize
            let minX = Self.valueLabelMinX(centerX: center, width: size.width, minX: sliderSpan.minX, maxX: sliderSpan.maxX)
            let minY = (self.valueLabelsView.bounds.height - size.height) / 2
            label.frame = CGRect(x: (minX / pixel).rounded() * pixel, y: (minY / pixel).rounded() * pixel,
                                 width: size.width, height: size.height)
        }
    }
    
    /// Left edge of a number centred on `centerX`, shifted inward just enough to stay within minX...maxX.
    static func valueLabelMinX(centerX: CGFloat, width: CGFloat, minX: CGFloat, maxX: CGFloat) -> CGFloat {
        return max(min(centerX - width / 2, maxX - width), minX)
    }
    
    /// Largest uniform font scale, from 1 down to the minimum, at which adjacent numbers (centred and clamped
    /// as in valueLabelMinX) keep the valueLabelMinimumGap target. Widths are measured at scale 1 and scaled linearly.
    static func valueLabelFontScale(centers: [CGFloat], widths: [CGFloat], minX: CGFloat, maxX: CGFloat) -> CGFloat {
        func fits(_ scale: CGFloat) -> Bool {
            let frames = zip(centers, widths).map { center, width -> (minX: CGFloat, maxX: CGFloat) in
                let left = Self.valueLabelMinX(centerX: center, width: width * scale, minX: minX, maxX: maxX)
                return (left, left + width * scale)
            }
            return zip(frames, frames.dropFirst()).allSatisfy { $1.minX - $0.maxX >= Self.valueLabelMinimumGap }
        }
        let candidates = stride(from: CGFloat(1), to: Self.valueLabelMinimumFontScale, by: -0.05)
        return candidates.first(where: fits) ?? Self.valueLabelMinimumFontScale
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
