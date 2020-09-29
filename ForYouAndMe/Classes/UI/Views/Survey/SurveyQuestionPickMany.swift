//
//  SurveyQuestionPickMany.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 29/09/2020.
//

import Foundation
import RxSwift

class SurveyQuestionPickMany: UIView {
    
    var surveyQuestion: SurveyQuestion
    var answers: [String] = [String]()
    
    fileprivate static let optionWidth: CGFloat = 74.0
    
    private lazy var scrollStackView: ScrollStackView = {
        let scrollStackView = ScrollStackView(axis: .vertical, horizontalInset: 0.0)
        scrollStackView.stackView.distribution = .fill
        return scrollStackView
    }()
    
    private final let disposeBag = DisposeBag()
    
    init(surveyQuestion: SurveyQuestion) {
        guard surveyQuestion.options != nil else {
            fatalError("Pick One question need options")
        }
        self.surveyQuestion = surveyQuestion
        super.init(frame: .zero)
        self.addSubview(self.scrollStackView)
        self.scrollStackView.autoPinEdgesToSuperviewEdges()
        
        self.scrollStackView.stackView.addBlankSpace(space: 40)
        
        let options = self.surveyQuestion.options
        options?.forEach({ option in
            let horizontalStackView = UIStackView()
            horizontalStackView.axis = .horizontal
            
            horizontalStackView.addBlankSpace(space: 30)
            // CheckBox
            let checkBox = GenericCheckboxView(isDefaultChecked: false, styleCategory: .primary)
            checkBox.tag = Int(option.id) ?? -1
            horizontalStackView.addArrangedSubview(checkBox)
            checkBox.isCheckedSubject
                .subscribe(onNext: { check in
                    print(check)
                })
                .disposed(by: self.disposeBag)
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
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func buttonPressed(button: UIButton) {
        
    }
}
