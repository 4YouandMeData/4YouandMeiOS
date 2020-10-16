//
//  SurveyQuestionViewController.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 25/09/2020.
//

import UIKit

struct SurveyQuestionPageData {
    let question: SurveyQuestion
    let questionNumber: Int
    let totalQuestions: Int
}

protocol SurveyQuestionViewCoordinator {
    func onSurveyQuestionAnsweredSuccess(result: SurveyResult)
    func onSurveyQuestionSkipped(questionId: String)
}

class SurveyQuestionViewController: UIViewController,
                                    SurveyQuestionProtocol {
    
    private let pageData: SurveyQuestionPageData
    private let coordinator: SurveyQuestionViewCoordinator
    
    private lazy var confirmButtonView: GenericButtonView = {
        let view = GenericButtonView(withImageStyleCategory: .secondaryBackground)
        view.addTarget(target: self, action: #selector(self.confirmButtonPressed))
        return view
    }()
    
    private var answer: Any? {
        didSet {
            self.updateConfirmButton()
        }
    }
    
    init(withPageData pageData: SurveyQuestionPageData,
         coordinator: SurveyQuestionViewCoordinator) {
        
        self.pageData = pageData
        self.coordinator = coordinator
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = ColorPalette.color(withType: .secondary)
        
        self.title = StringsProvider.string(forKey: .surveyStepsCount,
                                            withParameters: ["\(self.pageData.questionNumber)",
                                                             "\(self.pageData.totalQuestions)"])
        
        // StackView
        let stackView = UIStackView.create(withAxis: .vertical)
        self.view.addSubview(stackView)
        stackView.autoPinEdgesToSuperviewSafeArea(with: UIEdgeInsets(top: 0,
                                                                     left: Constants.Style.DefaultHorizontalMargins,
                                                                     bottom: 0,
                                                                     right: Constants.Style.DefaultHorizontalMargins),
                                                  excludingEdge: .bottom)
        
        stackView.addBlankSpace(space: 50.0)
        // Image
        stackView.addHeaderImage(image: self.pageData.question.image, height: 54.0)
        stackView.addBlankSpace(space: 40.0)
        // Title
        
        let attributedString = NSAttributedString.create(withText: self.pageData.question.body,
                                                         fontStyle: .title,
                                                         colorType: .primaryText)
        let label = UILabel()
        label.attributedText = attributedString
        label.numberOfLines = 0
        stackView.addArrangedSubview(label)
        label.setContentHuggingPriority(UILayoutPriority(1000), for: .vertical)
        
        let questionPicker = SurveyQuestionPickerFactory.getSurveyQuestionPicker(for: self.pageData.question, delegate: self)
        
        stackView.addArrangedSubview(questionPicker)
        
        // Bottom View
        self.view.addSubview(self.confirmButtonView)
        self.confirmButtonView.autoPinEdgesToSuperviewSafeArea(with: UIEdgeInsets.zero, excludingEdge: .top)
        stackView.autoPinEdge(.bottom, to: .top, of: self.confirmButtonView)
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.tapView))
        self.view.addGestureRecognizer(tap)
        
        self.updateConfirmButton()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.secondary(hidden: false).style)
        self.addCustomBackButton()
        self.addSkipButton()
    }
    
    // MARK: - Actions
    
    @objc private func tapView() {
        self.view.endEditing(true)
    }
    
    @objc private func confirmButtonPressed() {
        guard let answer = self.answer else {
            assertionFailure("Missing selected possible answer")
            return
        }
        let result = SurveyResult(question: self.pageData.question, answer: answer)
        self.coordinator.onSurveyQuestionAnsweredSuccess(result: result)
    }
    
    @objc private func skipButtonPressed() {
        self.coordinator.onSurveyQuestionSkipped(questionId: self.pageData.question.id)
    }
    
    // MARK: - Private Methods
    
    private func addSkipButton() {
        assert(self.navigationController != nil, "Missing UINavigationController")
        let buttonItem = UIBarButtonItem(title: StringsProvider.string(forKey: .surveyButtonSkip),
                                         style: .plain,
                                         target: self,
                                         action: #selector(self.skipButtonPressed))
        buttonItem.setTitleTextAttributes([
            .foregroundColor: ColorPalette.color(withType: .primary),
            .font: FontPalette.fontStyleData(forStyle: .header3).font
            ], for: .normal)
        self.navigationItem.rightBarButtonItem = buttonItem
    }
    
    private func updateConfirmButton() {
        self.confirmButtonView.setButtonEnabled(enabled: self.answer != nil)
    }
    
    // MARK: Delegate
    func answerDidChange(_ surveyQuestion: SurveyQuestion, answer: Any) {
        print("SurveyQuestionViewController - Answer Did Change: \(answer)")
        self.answer = answer
    }
}
