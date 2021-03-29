//
//  SurveyQuestionPickOne.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 28/09/2020.
//

class SurveyQuestionPickOne: UIView {
    
    private var surveyQuestion: SurveyQuestion
    private static let optionWidth: CGFloat = 74.0
    private var currentIndexSelected: Int = 0
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
                button.imageView?.tintColor = ColorPalette.color(withType: .primary)
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
            
            self.stackView.addArrangedSubview(horizontalStackView)
            self.stackView.addBlankSpace(space: 20)
            
            if option.isOther == true {
                let horizontalStackView = UIStackView()
                horizontalStackView.axis = .horizontal
                let tag = Int(String(repeating: option.id, count: 3))
                horizontalStackView.tag = tag ?? 111
                // Label
                let answerTextField = GenericTextFieldView(keyboardType: .default, styleCategory: .primary)
                answerTextField.delegate = self
                answerTextField.textField.placeholder = StringsProvider.string(forKey: .placeholderOtherField)
                let answerContainerView = UIView()
                answerContainerView.addSubview(answerTextField)
                answerTextField.autoPinEdge(toSuperviewEdge: .leading)
                answerTextField.autoPinEdge(toSuperviewEdge: .trailing)
                answerTextField.autoPinEdge(toSuperviewEdge: .top, withInset: 0, relation: .greaterThanOrEqual)
                answerTextField.autoPinEdge(toSuperviewEdge: .bottom, withInset: 0, relation: .greaterThanOrEqual)
                answerTextField.autoAlignAxis(toSuperviewAxis: .horizontal)
                horizontalStackView.addArrangedSubview(answerContainerView)
                horizontalStackView.isHidden = true
                self.stackView.addArrangedSubview(horizontalStackView)
            }
            
            if option.isOther == true {
                let isOtherView = self.getIsOtherView(tag: option.id)
                UIView.animate(withDuration: 0.2) {
                    isOtherView?.isHidden = !(self.currentIndexSelected == button.tag)
                    let textfield = isOtherView?.findViews(subclassOf: GenericTextFieldView.self).first
                    textfield?.text = ""
                }
            }
        })
    }
    
    @objc func buttonPressed(button: UIButton) {
        self.currentIndexSelected = button.tag
        self.updateAnswers()
        self.refresh()
    }
    
    private func getIsOtherView(tag: String) -> UIView? {
        let tag = Int(String(repeating: tag, count: 3))
        let view = self.stackView.subviews.filter({$0.tag == tag}).first
        return view
    }
    
    private func updateAnswers() {
        var surveyResponse: SurveyPickResponse = SurveyPickResponse(answerId: "\(self.currentIndexSelected)")
        let isOther = self.getIsOtherView(tag: "\(self.currentIndexSelected)")
        if isOther != nil {
            let textfield = isOther?.findViews(subclassOf: GenericTextFieldView.self).first
            surveyResponse.answerText = textfield?.text
        }
        self.delegate?.answerDidChange(self.surveyQuestion,
                                       answer: surveyResponse)
    }
}

extension SurveyQuestionPickOne: GenericTextFieldViewDelegate {
    func genericTextFieldShouldReturn(textField: GenericTextFieldView) -> Bool {
        self.updateAnswers()
        return self.endEditing(true)
    }
    
    func genericTextFieldDidChange(textField: GenericTextFieldView) {
        self.updateAnswers()
    }
}
