//
//  SurveyQuestionTextinput.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 29/09/2020.
//

class SurveyQuestionTextInput: UIView, UITextViewDelegate {
    
    var surveyQuestion: SurveyQuestion
    var answer: String = String()
    var labelLimit: UILabel = {
        let label = UILabel()
        label.textAlignment = .right
        label.font = FontPalette.fontStyleData(forStyle: .header3).font
        label.textColor = ColorPalette.color(withType: .inactive)
        return label
    }()
    
    private var placeholderLabel: UILabel!
    private var maxCharacters: Int = 0
    fileprivate static let optionWidth: CGFloat = 74.0
    
    init(surveyQuestion: SurveyQuestion) {
        self.surveyQuestion = surveyQuestion
        super.init(frame: .zero)
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        self.addSubview(stackView)
        stackView.autoPinEdgesToSuperviewEdges()
        
        stackView.addBlankSpace(space: 30)
        self.placeholderLabel = UILabel()
        self.placeholderLabel.text = self.surveyQuestion.placeholder
        self.placeholderLabel.font = FontPalette.fontStyleData(forStyle: .paragraph).font
        self.placeholderLabel.textColor = ColorPalette.color(withType: .inactive)
        self.placeholderLabel.sizeToFit()
        let textView = UITextView()
        textView.delegate = self
        textView.tintColor = ColorPalette.color(withType: .primary)
        textView.font = FontPalette.fontStyleData(forStyle: .header3).font
        textView.layer.borderWidth = 1
        textView.layer.borderColor = ColorPalette.color(withType: .inactive).cgColor
        textView.addSubview(self.placeholderLabel)
        self.placeholderLabel.isHidden = !textView.text.isEmpty
        self.placeholderLabel.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: CGFloat(textView.font!.pointSize/2),
                                                                              left: 5,
                                                                              bottom: 10,
                                                                              right: 10))
        self.maxCharacters = self.surveyQuestion.maxCharacters ?? 250
        stackView.addArrangedSubview(textView)
        stackView.addBlankSpace(space: 5)
        self.labelLimit.text = "\(textView.text.count) / \(self.maxCharacters)"
        stackView.addArrangedSubview(self.labelLimit)
        
        stackView.addBlankSpace(space: 15)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        self.placeholderLabel.isHidden = !textView.text.isEmpty
    }
    
    func textViewDidChange(_ textView: UITextView) {
        self.placeholderLabel.isHidden = !textView.text.isEmpty
        self.labelLimit.text = "\(textView.text.count) / \(self.maxCharacters)"
        if textView.text.count <= self.maxCharacters {
            textView.layer.borderColor = ColorPalette.color(withType: .inactive).cgColor
            self.labelLimit.textColor = ColorPalette.color(withType: .inactive)
        } else {
            textView.layer.borderColor = UIColor.red.cgColor
            self.labelLimit.textColor = .red
        }
    }
}
