//
//  SurveyClickableImage.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 18/04/25.
//

class SurveyClickableImage: UIView {
    
    private var surveyQuestion: SurveyQuestion
    private weak var delegate: SurveyQuestionProtocol?
    private var answers: [SurveyClickableResponse] = []
    private let imageView: UIImageView
    
    init(surveyQuestion: SurveyQuestion, delegate: SurveyQuestionProtocol) {
        self.surveyQuestion = surveyQuestion
        self.delegate = delegate
        
        guard let image = surveyQuestion.clickableImage else {
            fatalError("Missing clickable image")
        }
        
        // Init imageView early so we can use it for constraints
        self.imageView = UIImageView(image: image)
        super.init(frame: .zero)
        
        self.backgroundColor = .clear
        
        // 1. Add spacer (top margin)
        let spacer = UIView()
        spacer.backgroundColor = .clear
        self.addSubview(spacer)
        spacer.autoPinEdge(toSuperviewEdge: .top)
        spacer.autoPinEdge(toSuperviewEdge: .leading)
        spacer.autoPinEdge(toSuperviewEdge: .trailing)
        spacer.autoSetDimension(.height, toSize: 32)
        
        // 2. Add imageView
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        imageView.setContentHuggingPriority(.required, for: .vertical)
        imageView.setContentCompressionResistancePriority(.required, for: .vertical)
        
        self.addSubview(imageView)
        imageView.autoPinEdge(.top, to: .bottom, of: spacer)
        imageView.autoPinEdge(toSuperviewEdge: .leading, withInset: Constants.Style.DefaultHorizontalMargins / 2)
        imageView.autoPinEdge(toSuperviewEdge: .trailing, withInset: Constants.Style.DefaultHorizontalMargins / 2)
        
        // 3. Aspect ratio (maintains image shape)
        let aspectRatio = image.size.height / image.size.width
        imageView.autoMatch(.height, to: .width, of: imageView, withMultiplier: aspectRatio)
        
        // Reset button setup
        let resetButton = UIButton()
        var config = UIButton.Configuration.filled()
        config.title = StringsProvider.string(forKey: .resetDots)
        let resetIcon = ImagePalette.templateImage(withName: .resetDots)
        config.image = resetIcon
        config.imagePlacement = .leading
        config.imagePadding = 8
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.systemFont(ofSize: 16, weight: .medium)
            return outgoing
        }
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
        config.cornerStyle = .capsule
        config.baseBackgroundColor = ColorPalette.color(withType: .primary)
        config.baseForegroundColor = ColorPalette.color(withType: .secondaryText)
        resetButton.configuration = config
        resetButton.addTarget(self, action: #selector(resetClicks), for: .touchUpInside)
        self.addSubview(resetButton)
        resetButton.autoAlignAxis(toSuperviewAxis: .vertical)
        resetButton.autoPinEdge(.top, to: .bottom, of: imageView, withOffset: 16)

        // Bottom pin for intrinsic height
        resetButton.autoPinEdge(toSuperviewEdge: .bottom, withInset: 16)

        // Single Tap gesture
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.imageTapped(_:)))
        imageView.addGestureRecognizer(tap)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Tap Handling
    
    @objc private func imageTapped(_ recognizer: UITapGestureRecognizer) {
        
        let point = recognizer.location(in: imageView)
        
        let width = imageView.bounds.width
        let height = imageView.bounds.height
        
        guard width > 0, height > 0 else { return }
        
        // Check if we've reached the max number of clicks
        if let maxClicks = surveyQuestion.maxClick, answers.count >= maxClicks {
            // Provide haptic feedback to signal "no more clicks allowed"
            let feedback = UINotificationFeedbackGenerator()
            feedback.notificationOccurred(.error)
            return
        }
        
        let percentX = point.x / width
        let percentY = point.y / height
        
        let response = SurveyClickableResponse(
            top: Double(percentY * 100),
            left: Double(percentX * 100)
            )
            
        answers.append(response)
        drawDot(at: point, in: imageView)
        delegate?.answerDidChange(self.surveyQuestion, answer: self.answers)
    }
    
    /// Resets all recorded clicks and removes their dots from the view.
    @objc private func resetClicks() {
        answers.removeAll()
        
        // Remove all dot subviews from the imageView
        imageView.subviews.forEach { $0.removeFromSuperview() }
        delegate?.answerDidChange(self.surveyQuestion, answer: self.answers)
    }
    
    private func drawDot(at point: CGPoint, in imageView: UIImageView) {
        let dotDiameter: CGFloat = 10
        let dot = UIView()
        dot.backgroundColor = .red
        dot.layer.cornerRadius = dotDiameter / 2
        imageView.addSubview(dot)
        
        dot.autoSetDimensions(to: CGSize(width: dotDiameter, height: dotDiameter))
        dot.autoPinEdge(.leading, to: .leading, of: imageView, withOffset: point.x - dotDiameter / 2)
        dot.autoPinEdge(.top, to: .top, of: imageView, withOffset: point.y - dotDiameter / 2)
    }
}

struct SurveyClickableResponse: Equatable, Codable {
    var top: Double
    var left: Double
}
