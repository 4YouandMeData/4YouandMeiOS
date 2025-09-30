//
//  SurveyQuestionPickMany.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 29/09/2020.
//

import Foundation
import RxSwift

class SurveyQuestionPickMany: UIView {
    
    private var surveyQuestion: SurveyQuestion
    private var answers: [String: Bool] = [String: Bool]()
    
    private static let optionWidth: CGFloat = 74.0
    private weak var delegate: SurveyQuestionProtocol?
    
    private let stackView = UIStackView.create(withAxis: .vertical)
    private var checkBoxAnswers: [GenericCheckboxView] = []
    
    private final let disposeBag = DisposeBag()
    
    init(surveyQuestion: SurveyQuestion, delegate: SurveyQuestionProtocol) {
        guard surveyQuestion.options != nil else {
            fatalError("Pick One question need options")
        }
        self.delegate = delegate
        self.surveyQuestion = surveyQuestion
        super.init(frame: .zero)
        self.addSubview(self.stackView)
        self.stackView.autoPinEdgesToSuperviewEdges()
        
        self.stackView.addBlankSpace(space: 40)
        
        let options = self.surveyQuestion.options
        options?.forEach({ option in
            let horizontalStackView = UIStackView()
            horizontalStackView.axis = .horizontal
            
            horizontalStackView.addBlankSpace(space: 30)
            
            // CheckBox
            let checkBox = GenericCheckboxView(isDefaultChecked: false, styleCategory: .primary)
            checkBox.tag = Int(option.id) ?? -1
            checkBox.isCheckedSubject
                .subscribe(onNext: { [weak self] check in
                    guard let self = self else { return }
                    if check {
                        if option.isNone == true {
                            let isNotNoneOptions = options?.filter({$0.isNone == false || $0.isNone == nil})
                            isNotNoneOptions?.forEach({ isNotNoneOption in
                                let isNotNoneViews = self.checkBoxAnswers.filter({$0.tag == Int(isNotNoneOption.id)})
                                isNotNoneViews.forEach({view in
                                    view.isCheckedSubject.accept(false)
                                })
                                self.answers.updateValue(false, forKey: "\(isNotNoneOption.id)")
                            })
                        } else {
                            let isNoneOptions = options?.filter({$0.isNone == true})
                            isNoneOptions?.forEach({ isNoneOption in
                                let isNoneViews = self.checkBoxAnswers.filter({$0.tag == Int(isNoneOption.id)})
                                isNoneViews.forEach({view in
                                    view.isCheckedSubject.accept(false)
                                })
                                self.answers.updateValue(false, forKey: "\(isNoneOption.id)")
                            })
                        }
                    }
                    if option.isOther == true {
                        let isOtherView = self.getIsOtherView(tag: option.id)
                        UIView.animate(withDuration: 0.2) { [weak self, weak isOtherView] in
                            guard let isOtherView = isOtherView else { return }
                            let hideOtherView = !check
                            // Need to avoid re-assigning the same value to isHidden for views inside UIStackView.
                            // It will cause views to be hidden or not to be hidden correctly sometimes (FYAM-791).
                            // In our case, this happened only when in particular cases and only if animating.
                            // Seems related to this Apple bug: http://www.openradar.me/25087688
                            // See this discussion:
                            // https://stackoverflow.com/questions/43831695/stackview-ishidden-attribute-not-updating-as-expected
                            if isOtherView.isHidden != hideOtherView {
                                isOtherView.isHidden = hideOtherView
                                let textfield = isOtherView.findViews(subclassOf: GenericTextFieldView.self).first
                                textfield?.text = ""
                                if !check {
                                    self?.endEditing(true)
                                }
                                self?.stackView.layoutIfNeeded()
                            }
                        }
                    }
                    self.answers.updateValue(check, forKey: "\(checkBox.tag)")
                    self.updateAnswers()
                })
                .disposed(by: self.disposeBag)
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.surveyQuestion(self.surveyQuestion, didUpdateValidity: false)
            }
            
            self.checkBoxAnswers.append(checkBox)
            let checkBoxContainerView = UIView()
            checkBoxContainerView.addSubview(checkBox)
            checkBox.autoPinEdge(toSuperviewEdge: .leading)
            checkBox.autoPinEdge(toSuperviewEdge: .trailing)
            checkBox.autoPinEdge(toSuperviewEdge: .top, withInset: 0, relation: .greaterThanOrEqual)
            checkBox.autoPinEdge(toSuperviewEdge: .bottom, withInset: 0, relation: .greaterThanOrEqual)
            checkBox.autoAlignAxis(toSuperviewAxis: .horizontal)
            horizontalStackView.addArrangedSubview(checkBoxContainerView)
            
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
                // Label
                let answerTextField = GenericTextFieldView(keyboardType: .default, styleCategory: .primary)
                answerTextField.delegate = self
                answerTextField.textField.placeholder = StringsProvider.string(forKey: .placeholderOtherField)
                let answerContainerView = UIView()
                let tag = Int(String(repeating: option.id, count: 3))
                answerContainerView.tag = tag ?? 111
                answerContainerView.addSubview(answerTextField)
                answerTextField.autoPinEdge(toSuperviewEdge: .leading)
                answerTextField.autoPinEdge(toSuperviewEdge: .trailing)
                answerTextField.autoPinEdge(toSuperviewEdge: .top, withInset: 0, relation: .greaterThanOrEqual)
                answerTextField.autoPinEdge(toSuperviewEdge: .bottom, withInset: 0, relation: .greaterThanOrEqual)
                answerTextField.autoAlignAxis(toSuperviewAxis: .horizontal)
                answerContainerView.isHidden = true
                self.stackView.addArrangedSubview(answerContainerView)
            }
        })
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func getIsOtherView(tag: String) -> UIView? {
        let tag = Int(String(repeating: tag, count: 3))
        let view = self.stackView.subviews.filter({$0.tag == tag}).first
        return view
    }
    
    func updateAnswers() {
        let answers = self.answers.filter({ $1 == true })
            .map { $0.key }
        
        var surveyResponses: [SurveyPickResponse] = []
        answers.forEach { answerTag in
            var surveyResponse: SurveyPickResponse = SurveyPickResponse(answerId: answerTag)
            let isOther = self.getIsOtherView(tag: answerTag)
            if isOther != nil {
                let textfield = isOther?.findViews(subclassOf: GenericTextFieldView.self).first
                surveyResponse.answerText = textfield?.text
            }
            surveyResponses.append(surveyResponse)
        }
        self.delegate?.answerDidChange(self.surveyQuestion,
                                           answer: surveyResponses)
        
        let isValid = !surveyResponses.isEmpty
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.surveyQuestion(self.surveyQuestion, didUpdateValidity: isValid)
        }
    }
}

extension SurveyQuestionPickMany: GenericTextFieldViewDelegate {
    func genericTextFieldShouldReturn(textField: GenericTextFieldView) -> Bool {
        self.updateAnswers()
        return self.endEditing(true)
    }
    
    func genericTextFieldDidChange(textField: GenericTextFieldView) {
        self.updateAnswers()
    }
}

struct SurveyPickResponse: Equatable {
    var answerId: String
    var answerText: String?
}

extension SurveyPickResponse: Codable {
    enum CodingKeys: String, CodingKey {
        case answerId = "answer_id"
        case answerText = "answer_text"
    }
}

extension UIView {
    func findViews<T: UIView>(subclassOf: T.Type) -> [T] {
        return recursiveSubviews.compactMap { $0 as? T }
    }

    var recursiveSubviews: [UIView] {
        return subviews + subviews.flatMap { $0.recursiveSubviews }
    }
}
