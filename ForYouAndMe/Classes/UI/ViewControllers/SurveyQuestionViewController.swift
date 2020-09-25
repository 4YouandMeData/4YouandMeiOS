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
    func onSurveyQuestionAnsweredSuccess(answer: SurveyResult)
    func onSurveyQuestionSkipped(questionId: String)
}

class SurveyQuestionViewController: UIViewController {
    
    private let pageData: SurveyQuestionPageData
    private let coordinator: SurveyQuestionViewCoordinator
    
    private lazy var confirmButtonView: GenericButtonView = {
        let view = GenericButtonView(withImageStyleCategory: .primaryBackground)
        view.addTarget(target: self, action: #selector(self.confirmButtonPressed))
        return view
    }()
    
    private var answer: Any? {
        didSet {
            self.updateConfirmButton()
        }
    }
    
    init(withPageData pageData: SurveyQuestionPageData, coordinator: SurveyQuestionViewCoordinator) {
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
        
        // ScrollStackView
        let scrollStackView = ScrollStackView(axis: .vertical, horizontalInset: Constants.Style.DefaultHorizontalMargins)
        self.view.addSubview(scrollStackView)
        scrollStackView.autoPinEdgesToSuperviewSafeArea(with: .zero, excludingEdge: .bottom)
        
        scrollStackView.stackView.addBlankSpace(space: 50.0)
        // Image
        scrollStackView.stackView.addHeaderImage(image: self.pageData.question.image, height: 54.0)
        scrollStackView.stackView.addBlankSpace(space: 40.0)
        // Title
        scrollStackView.stackView.addLabel(withText: self.pageData.question.body,
                                           fontStyle: .title,
                                           colorType: .primaryText)
        scrollStackView.stackView.addBlankSpace(space: 40.0)
        
        // Bottom View
        let bottomView = GenericButtonView(withImageStyleCategory: .secondaryBackground)
        bottomView.addTarget(target: self, action: #selector(self.confirmButtonPressed))
        self.view.addSubview(bottomView)
        bottomView.autoPinEdgesToSuperviewSafeArea(with: UIEdgeInsets.zero, excludingEdge: .top)
        scrollStackView.scrollView.autoPinEdge(.bottom, to: .top, of: bottomView)
        
        // TODO: Survey picker view
        
        // TODO: Remove (Test Purpose)
        self.answer = 2
        
        self.updateConfirmButton()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.secondary(hidden: false).style)
        self.addCustomBackButton()
        self.addSkipButton()
    }
    
    // MARK: - Actions
    
    @objc private func confirmButtonPressed() {
        guard let answer = self.answer else {
            assertionFailure("Missing selected possible answer")
            return
        }
        let result = SurveyResult(questionId: self.pageData.question.id, answer: answer)
        self.coordinator.onSurveyQuestionAnsweredSuccess(answer: result)
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
}
