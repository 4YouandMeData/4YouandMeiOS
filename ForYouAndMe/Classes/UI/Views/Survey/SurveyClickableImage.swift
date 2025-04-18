//
//  SurveyClickableImage.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 18/04/25.
//

class SurveyClickableImage: UIView {
    
    private var surveyQuestion: SurveyQuestion
    private weak var delegate: SurveyQuestionProtocol?
    private var answers: [String: String] = [String: String]()
    
    init(surveyQuestion: SurveyQuestion, delegate: SurveyQuestionProtocol) {
        
        self.surveyQuestion = surveyQuestion
        self.delegate = delegate
        
        super.init(frame: .zero)
        self.backgroundColor = .red
        
        guard let image = surveyQuestion.clickableImage else {
            fatalError("Clickeable image is missing")
        }
        
        let spacerView = UIView()
        spacerView.backgroundColor = .clear
        self.addSubview(spacerView)
        
        // Pin spacer to top, leading, and trailing edges
        spacerView.autoPinEdge(toSuperviewEdge: .top)
        spacerView.autoPinEdge(toSuperviewEdge: .leading)
        spacerView.autoPinEdge(toSuperviewEdge: .trailing)
        spacerView.autoSetDimension(.height, toSize: 32)
        
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        
        // Prevent the image view from stretching vertically
        imageView.setContentHuggingPriority(.required, for: .vertical)
        imageView.setContentCompressionResistancePriority(.required, for: .vertical)
        
        self.addSubview(imageView)
        
        // Pin the image view just below the spacer, and to the leading/trailing edges
        imageView.autoPinEdge(.top, to: .bottom, of: spacerView)
        imageView.autoPinEdge(toSuperviewEdge: .leading, withInset: Constants.Style.DefaultHorizontalMargins/2)
        imageView.autoPinEdge(toSuperviewEdge: .trailing, withInset: Constants.Style.DefaultHorizontalMargins/2)
        
        // 3. Maintain the image's aspect ratio: height = width * (originalHeight/originalWidth)
        let aspectRatio = image.size.height / image.size.width
        imageView.autoMatch(.height, to: .width, of: imageView, withMultiplier: aspectRatio)
        
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
