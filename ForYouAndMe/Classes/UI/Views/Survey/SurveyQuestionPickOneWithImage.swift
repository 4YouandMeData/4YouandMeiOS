//
//  SurveyQuestionPickOneWithImage.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 09/07/25.
//

class SurveyQuestionPickOneWithImage: UIView {
    
    private var surveyQuestion: SurveyQuestion
    private static let optionWidth: CGFloat = 74.0
    private var currentIndexSelected: String?
    private weak var delegate: SurveyQuestionProtocol?
    
    private let stackView = UIStackView.create(withAxis: .vertical)
    
    init(surveyQuestion: SurveyQuestion, delegate: SurveyQuestionProtocol) {
        guard surveyQuestion.options != nil else {
            fatalError("Pick One question need options")
        }
        self.delegate = delegate
        self.surveyQuestion = surveyQuestion
        super.init(frame: .zero)
        self.addSubview(self.stackView)
        self.stackView.autoPinEdgesToSuperviewEdges()
        self.refresh()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func refresh() {
        self.stackView.arrangedSubviews.forEach({$0.removeFromSuperview()})
        self.stackView.addBlankSpace(space: 40)
        
        for (index, option) in (self.surveyQuestion.options ?? []).enumerated() {
            let optionView = createOptionView(for: option, index: index)
            self.stackView.addArrangedSubview(optionView)
            self.stackView.addBlankSpace(space: 12)
        }
    }
    
    private func createOptionView(for option: SurveyQuestionOption, index: Int) -> UIView {
        let isSelected = option.id == self.currentIndexSelected
        
        let container = UIView()
        container.layer.cornerRadius = 12
        container.layer.borderWidth = 1
        container.layer.borderColor = isSelected
        ? ColorPalette.color(withType: .primary).cgColor
        : ColorPalette.color(withType: .inactive).cgColor
        container.backgroundColor = isSelected
        ? ColorPalette.color(withType: .primary)
        : ColorPalette.color(withType: .inactive)
        
        // Interactions
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(optionTapped(_:)))
        container.addGestureRecognizer(tapGesture)
        container.tag = Int(option.id) ?? 0
        
        let horizontalStack = UIStackView()
        horizontalStack.axis = .horizontal
        horizontalStack.spacing = 12
        horizontalStack.alignment = .center
        
        container.addSubview(horizontalStack)
        horizontalStack.autoPinEdgesToSuperviewEdges(with: .init(top: 12, left: 12, bottom: 12, right: 12))
        
        // Image
        if let image = option.previewImage {
            let imageView = UIImageView(image: image)
            imageView.contentMode = .scaleAspectFit
            let imageWidth = min(UIScreen.main.bounds.width * 0.25, 100)
            imageView.autoSetDimension(.width, toSize: imageWidth)
            
            imageView.tag = index
            imageView.isUserInteractionEnabled = true

            let tap = UITapGestureRecognizer(target: self, action: #selector(imageTapped(_:)))
            imageView.addGestureRecognizer(tap)
            horizontalStack.addArrangedSubview(imageView)
        }

        // Label
        let textColor: UIColor = isSelected
        ? ColorPalette.color(withType: .secondaryText)
        : ColorPalette.color(withType: .primaryText)

        let label = UILabel()
        label.numberOfLines = 0
        label.attributedText = NSAttributedString.create(
            withText: option.value,
            fontStyle: .paragraph,
            color: textColor,
            textAlignment: .left)
        
        horizontalStack.addArrangedSubview(label)

        // Radio button
        let radioImage = isSelected
        ? ImagePalette.templateImage(withName: .radioButtonFilled)
        : ImagePalette.templateImage(withName: .radioButtonOutline)
        
        let radioButton = UIImageView(image: radioImage)
        radioButton.tintColor = isSelected
        ? ColorPalette.color(withType: .secondary)
        : .black
        radioButton.autoSetDimensions(to: CGSize(width: 24, height: 24))
        horizontalStack.addArrangedSubview(radioButton)
        
        return container
    }
    
    @objc private func optionTapped(_ gesture: UITapGestureRecognizer) {
        guard let id = gesture.view?.tag,
                let selectedId = surveyQuestion.options?.first(where: { Int($0.id) == id })?.id else { return }
        self.currentIndexSelected = selectedId
        self.updateAnswers()
        self.refresh()
    }
    
    private func updateAnswers() {
        guard let id = self.currentIndexSelected else { return }
        let response = SurveyPickResponse(answerId: id)
        self.delegate?.answerDidChange(self.surveyQuestion, answer: response)
    }
    
    @objc private func imageTapped(_ gesture: UITapGestureRecognizer) {
        guard let imageView = gesture.view as? UIImageView else { return }
        let index = imageView.tag
        
        guard let option = surveyQuestion.options?[safe: index],
              let fullImage = option.fullScreenImage else { return }

        let zoomVC = ImageZoomViewController(image: fullImage)
        self.findTopViewController()?.present(zoomVC, animated: true, completion: nil)

    }
    
    private func findTopViewController(base: UIViewController? = UIApplication.shared.windows.first(where: \.isKeyWindow)?.rootViewController) -> UIViewController? {
        if let nav = base as? UINavigationController {
            return findTopViewController(base: nav.visibleViewController)
        }
        if let tab = base as? UITabBarController {
            return findTopViewController(base: tab.selectedViewController)
        }
        if let presented = base?.presentedViewController {
            return findTopViewController(base: presented)
        }
        return base
    }
}
