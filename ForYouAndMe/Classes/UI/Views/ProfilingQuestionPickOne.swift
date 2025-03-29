//
//  ProfilingQuestionPickOne.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 28/03/25.
//

struct ProfilingPickResponse: Equatable {
    var answerId: String
    var answerPosition: String?
}

protocol ProfilingQuestionProtocol: AnyObject {
    func answerDidChange(_ profilingQuestion: ProfilingQuestion, answer: Any)
}

class ProfilingQuestionPickOne: UIView {
    
    private var profilingQuestion: ProfilingQuestion
    private static let optionWidth: CGFloat = 74.0
    private var currentIndexSelected: Int = 0
    private weak var delegate: ProfilingQuestionProtocol?
    
    private let stackView = UIStackView.create(withAxis: .vertical)
    
    init(profilingQuestion: ProfilingQuestion, delegate: ProfilingQuestionProtocol) {
        
        self.delegate = delegate
        self.profilingQuestion = profilingQuestion
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
        
        let options = self.profilingQuestion.profilingOptions
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
            answerLabel.attributedText = NSAttributedString.create(withText: option.text,
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
            
        })
    }
    
    @objc func buttonPressed(button: UIButton) {
        self.currentIndexSelected = button.tag
        self.updateAnswers()
        self.refresh()
    }
    
    private func updateAnswers() {
        let profilingResponse: ProfilingPickResponse = ProfilingPickResponse(answerId: "\(self.currentIndexSelected)")
        self.delegate?.answerDidChange(self.profilingQuestion,
                                       answer: profilingResponse)
    }
}
