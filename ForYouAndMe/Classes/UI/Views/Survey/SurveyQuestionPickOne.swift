//
//  SurveyQuestionPickOne.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 28/09/2020.
//

class SurveyQuestionPickOne: UIView {
    
    var surveyQuestion: SurveyQuestion
    
    fileprivate static let optionWidth: CGFloat = 74.0
    private var currentIndexSelected: Int = 0
    
    private lazy var scrollStackView: ScrollStackView = {
        let scrollStackView = ScrollStackView(axis: .vertical, horizontalInset: 0.0)
        scrollStackView.stackView.distribution = .fill
        return scrollStackView
    }()
    
    init(surveyQuestion: SurveyQuestion) {
        guard surveyQuestion.options != nil else {
            fatalError("Pick One question need options")
        }
        self.surveyQuestion = surveyQuestion
        super.init(frame: .zero)
        self.addSubview(self.scrollStackView)
        self.scrollStackView.autoPinEdgesToSuperviewEdges()
        self.refresh()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func refresh() {
        self.scrollStackView.stackView.arrangedSubviews.forEach({$0.removeFromSuperview()})
        self.scrollStackView.stackView.addBlankSpace(space: 40)
        
        let options = self.surveyQuestion.options
        options?.forEach({ option in
            let horizontalStackView = UIStackView()
            horizontalStackView.axis = .horizontal
            
            // button
            let button = UIButton()
            button.contentEdgeInsets = UIEdgeInsets(top: 8.0, left: 8.0, bottom: 8.0, right: 8.0)
            button.addTarget(self, action: #selector(self.buttonPressed), for: .touchUpInside)
            button.tag = Int(option.id) ?? 0
            if self.currentIndexSelected == button.tag {
                button.setImage(ImagePalette.templateImage(withName: .radioButtonFilled), for: .normal)
                button.imageView?.tintColor = ColorPalette.color(withType: .active)
            } else {
                button.setImage(ImagePalette.templateImage(withName: .radioButtonOutline), for: .normal)
                button.imageView?.tintColor = ColorPalette.color(withType: .inactive)
            }
            
            let buttonContainerView = UIView()
            buttonContainerView.addSubview(button)
            buttonContainerView.autoSetDimension(.width, toSize: Self.optionWidth)
            button.autoPinEdge(toSuperviewEdge: .leading)
            button.autoPinEdge(toSuperviewEdge: .trailing)
            button.autoPinEdge(toSuperviewEdge: .top, withInset: 0, relation: .greaterThanOrEqual)
            button.autoPinEdge(toSuperviewEdge: .bottom, withInset: 0, relation: .greaterThanOrEqual)
            button.autoAlignAxis(toSuperviewAxis: .horizontal)
            horizontalStackView.addArrangedSubview(buttonContainerView)
            
            // Label
            let answerLabel = UILabel()
            answerLabel.numberOfLines = 0
            answerLabel.attributedText = NSAttributedString.create(withText: option.value,
                                                                   fontStyle: .paragraph,
                                                                   color: ColorPalette.color(withType: .primaryText),
                                                                   textAlignment: .left)
            let answerContainerView = UIView()
            answerContainerView.addSubview(answerLabel)
            answerLabel.autoPinEdge(toSuperviewEdge: .leading)
            answerLabel.autoPinEdge(toSuperviewEdge: .trailing)
            answerLabel.autoPinEdge(toSuperviewEdge: .top, withInset: 0, relation: .greaterThanOrEqual)
            answerLabel.autoPinEdge(toSuperviewEdge: .bottom, withInset: 0, relation: .greaterThanOrEqual)
            answerLabel.autoAlignAxis(toSuperviewAxis: .horizontal)
            horizontalStackView.addArrangedSubview(answerContainerView)
            
            self.scrollStackView.stackView.addArrangedSubview(horizontalStackView)
            self.scrollStackView.stackView.addBlankSpace(space: 20)
        })
    }
    
    @objc func buttonPressed(button: UIButton) {
        self.currentIndexSelected = button.tag
        self.refresh()
    }
}
