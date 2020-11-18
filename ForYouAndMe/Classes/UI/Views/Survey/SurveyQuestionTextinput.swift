//
//  SurveyQuestionTextinput.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 29/09/2020.
//

class SurveyQuestionTextInput: UIView, UITextViewDelegate {
    
    private var surveyQuestion: SurveyQuestion
    private var answer: String = String()
    
    private lazy var textView: UITextView = {
        
        // Text View
        let textView = UITextView()
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 8
        textView.typingAttributes = [.foregroundColor: ColorPalette.color(withType: .primaryText),
                                     .font: FontPalette.fontStyleData(forStyle: .header3).font,
                                     .paragraphStyle: style]
        textView.delegate = self
        textView.layer.borderWidth = 1
        textView.tintColor = ColorPalette.color(withType: .primary)
        textView.layer.borderColor = ColorPalette.color(withType: .inactive).cgColor
        
        // Toolbar
        let toolBar = UIToolbar()
        toolBar.barStyle = .default
        toolBar.isTranslucent = true
        toolBar.tintColor = ColorPalette.color(withType: .primary)
        toolBar.sizeToFit()
        
        let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(self.doneButtonPressed))
        let spaceButton = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        
        toolBar.setItems([spaceButton, doneButton], animated: false)
        textView.inputAccessoryView = toolBar
        
        return textView
    }()
    
    private lazy var placeholderLabel: UILabel = {
        let label = UILabel()
        label.text = self.surveyQuestion.placeholder
        label.font = FontPalette.fontStyleData(forStyle: .paragraph).font
        label.textColor = ColorPalette.color(withType: .inactive)
        label.sizeToFit()
        return label
    }()
    
    private var limitLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .right
        label.font = FontPalette.fontStyleData(forStyle: .header3).font
        label.textColor = ColorPalette.color(withType: .inactive)
        return label
    }()
    
    private let maxCharacters: Int
    private static let optionWidth: CGFloat = 74.0
    private weak var delegate: SurveyQuestionProtocol?
    
    init(surveyQuestion: SurveyQuestion, delegate: SurveyQuestionProtocol) {
        self.maxCharacters = surveyQuestion.maxCharacters ?? 250
        self.surveyQuestion = surveyQuestion
        self.delegate = delegate
        
        super.init(frame: .zero)
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        self.addSubview(stackView)
        stackView.autoPinEdgesToSuperviewEdges()
        
        stackView.addBlankSpace(space: 30)
        
        // TextView
        stackView.addArrangedSubview(self.textView)
        
        // Placeholder label
        self.textView.addSubview(self.placeholderLabel)
        self.placeholderLabel.isHidden = !textView.text.isEmpty
        self.placeholderLabel.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: CGFloat(self.textView.font!.pointSize/2),
                                                                              left: 5,
                                                                              bottom: 10,
                                                                              right: 10))
        
        stackView.addBlankSpace(space: 5)
        
        // Limit label
        self.limitLabel.text = "\(self.textView.text.count) / \(self.maxCharacters)"
        stackView.addArrangedSubview(self.limitLabel)
        
        stackView.addBlankSpace(space: 15)
        
        self.autoSetDimension(.height, toSize: Constants.Style.SurveyPickerDefaultHeight)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Actions
    
    @objc private func doneButtonPressed() {
        self.textView.resignFirstResponder()
    }
    
    // MARK: - UITextViewDelegate
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        self.placeholderLabel.isHidden = !textView.text.isEmpty
    }
    
    func textViewDidChange(_ textView: UITextView) {
        self.placeholderLabel.isHidden = !textView.text.isEmpty
        self.limitLabel.text = "\(textView.text.count) / \(self.maxCharacters)"
        if textView.text.count <= self.maxCharacters {
            textView.layer.borderColor = ColorPalette.color(withType: .inactive).cgColor
            self.limitLabel.textColor = ColorPalette.color(withType: .inactive)
        } else {
            textView.layer.borderColor = UIColor.red.cgColor
            self.limitLabel.textColor = .red
        }
        
        self.delegate?.answerDidChange(self.surveyQuestion, answer: textView.text ?? "")
    }
}
