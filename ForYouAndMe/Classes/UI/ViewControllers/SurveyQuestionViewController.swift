//
//  SurveyQuestionViewController.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 25/09/2020.
//

import UIKit
import TPKeyboardAvoiding

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
    private var shouldAbortOnSkip: Bool {
        return StringsProvider
            .string(forKey: .surveyButtonAbort)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() == "true"
    }
    
    private lazy var scrollView: UIScrollView = {
        let scrollView = TPKeyboardAvoidingScrollView()
        scrollView.keyboardDismissMode = .interactive
        return scrollView
    }()
    
    private lazy var progressView: UIProgressView = {
        let progressView = UIProgressView(progressViewStyle: .default)
        progressView.progressTintColor = ColorPalette.color(withType: .primary)
        progressView.trackTintColor = ColorPalette.color(withType: .fourthText).applyAlpha(0.3)
        progressView.translatesAutoresizingMaskIntoConstraints = false
        return progressView
    }()
    
    private lazy var progressValueLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.numberOfLines = 1
        label.font = FontPalette.fontStyleData(forStyle: .infoNote).font
        label.textColor = ColorPalette.color(withType: .primary)
        label.text = "0% completed"
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
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
        
        self.view.addSubview(self.progressView)
        self.progressView.autoPinEdgesToSuperviewSafeArea(with: UIEdgeInsets(top: 0.0,
                                                                             left: Constants.Style.DefaultHorizontalMargins,
                                                                             bottom: 0.0,
                                                                             right: Constants.Style.DefaultHorizontalMargins),
                                                          excludingEdge: .bottom)
        
        self.view.addSubview(self.progressValueLabel)
        self.progressValueLabel.autoPinEdge(.top,
                                            to: .bottom,
                                            of: self.progressView,
                                            withOffset: 8.0)
        self.progressValueLabel.autoAlignAxis(.vertical,
                                              toSameAxisOf: self.progressView)
        self.view.backgroundColor = ColorPalette.color(withType: .secondary)
        
        // ScrollView
        self.view.addSubview(self.scrollView)
        self.scrollView.autoPinEdgesToSuperviewSafeArea(with: .zero, excludingEdge: .bottom)
        
        // StackView
        let stackView = UIStackView.create(withAxis: .vertical)
        self.scrollView.addSubview(stackView)
        stackView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 0.0,
                                                                  left: Constants.Style.DefaultHorizontalMargins,
                                                                  bottom: 0.0,
                                                                  right: Constants.Style.DefaultHorizontalMargins))
        stackView.autoAlignAxis(toSuperviewAxis: .vertical)
        
        stackView.addBlankSpace(space: 60.0)
        // Image
        if let image = self.pageData.question.image {
            stackView.addHeaderImage(image: image, height: 54.0)
            stackView.addBlankSpace(space: 40.0)
        }
        // Title
        let attributedString = NSAttributedString.create(withText: self.pageData.question.body,
                                                         fontStyle: .header2,
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
        self.confirmButtonView.autoPinEdgesToSuperviewSafeArea(with: .zero, excludingEdge: .top)
        self.confirmButtonView.autoPinEdge(.top, to: .bottom, of: self.scrollView)
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.tapView))
        self.view.addGestureRecognizer(tap)
        
        let progressValue = Float(self.pageData.questionNumber) / Float(self.pageData.totalQuestions)
        self.progressView.setProgress(progressValue, animated: true)
        
        let percent = Int(progressValue * 100)
        progressValueLabel.text = "\(percent)% completed"
        
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
        if shouldAbortOnSkip {
            let alert = UIAlertController(
                title: StringsProvider.string(forKey: .surveyAbortTitle),
                message: StringsProvider.string(forKey: .surveyAbortMessage),
                preferredStyle: .alert
            )

            alert.addAction(UIAlertAction(
                title: StringsProvider.string(forKey: .surveyAbortCancel),
                style: .cancel,
                handler: nil
            ))

            alert.addAction(UIAlertAction(
                title: StringsProvider.string(forKey: .surveyAbortConfirm),
                style: .destructive,
                handler: { [weak self] _ in
                    guard let self = self else { return }

                    if let navigationController = self.navigationController {
                        navigationController.dismiss(animated: true)
                    } else {
                        self.dismiss(animated: true)
                    }
                }
            ))

            self.present(alert, animated: true)

        } else {
            self.coordinator.onSurveyQuestionSkipped(questionId: self.pageData.question.id)
        }
    }
    
    // MARK: - Private Methods
    
    private func addSkipButton() {
        assert(self.navigationController != nil, "Missing UINavigationController")
        if self.pageData.question.skippable {
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
    }
    
    private func updateConfirmButton() {
        self.confirmButtonView.setButtonEnabled(enabled: self.answer != nil)
    }
    
    // MARK: Delegate
    func answerDidChange(_ surveyQuestion: SurveyQuestion, answer: Any) {
        print("SurveyQuestionViewController - Answer Did Change: \(answer)")
        self.answer = answer
    }
    
    func surveyQuestion(_ question: SurveyQuestion, didUpdateValidity isValid: Bool) {
        self.confirmButtonView.setButtonEnabled(enabled: isValid)
    }
}
