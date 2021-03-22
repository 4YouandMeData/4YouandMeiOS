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
                .subscribe(onNext: { check in
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
                    self.answers.updateValue(check, forKey: "\(checkBox.tag)")
                    let answers = self.answers.filter({ $1 == true }).map { $0.key }
                    self.delegate?.answerDidChange(self.surveyQuestion,
                                                       answer: answers)
                })
                .disposed(by: self.disposeBag)
            
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
        })
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
