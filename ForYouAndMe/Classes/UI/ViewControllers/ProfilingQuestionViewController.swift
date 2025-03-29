//
//  ProfilingQuestionViewController.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 28/03/25.
//

import Foundation
import PureLayout
import TPKeyboardAvoiding

protocol ProfilingQuestionViewCoordinator {
    func onQuestionAnsweredSuccess(result: ProfilingResult)
}

class ProfilingQuestionViewController: UIViewController {
    
    private let pageData: ProfilingQuestion
    private let coordinator: ProfilingQuestionViewCoordinator
    
    private lazy var scrollView: UIScrollView = {
        let scrollView = TPKeyboardAvoidingScrollView()
        scrollView.keyboardDismissMode = .interactive
        return scrollView
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
    
    init(withPageData pageData: ProfilingQuestion,
         coordinator: ProfilingQuestionViewCoordinator) {
        
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
        
        stackView.addBlankSpace(space: 40.0)
        // Image
        if let image = self.pageData.image {
            stackView.addHeaderImage(image: image, height: 54.0)
            stackView.addBlankSpace(space: 40.0)
        }
        // Title
        let attributedString = NSAttributedString.create(withText: self.pageData.title,
                                                         fontStyle: .title,
                                                         colorType: .primaryText,
                                                         textAlignment: .left)
        let label = UILabel()
        label.attributedText = attributedString
        label.numberOfLines = 0
        stackView.addArrangedSubview(label)
        label.setContentHuggingPriority(UILayoutPriority(1000), for: .vertical)
        
        stackView.addBlankSpace(space: 24.0)
        
        // Body
        let attributedBodyString = NSAttributedString.create(withText: self.pageData.body,
                                                             fontStyle: .paragraph,
                                                             colorType: .primaryText,
                                                             textAlignment: .justified)
        let bodyLabel = UILabel()
        bodyLabel.attributedText = attributedBodyString
        bodyLabel.numberOfLines = 0
        stackView.addArrangedSubview(bodyLabel)
        bodyLabel.setContentHuggingPriority(UILayoutPriority(1000), for: .vertical)
        
        let questionPicker = ProfilingQuestionPickOne(profilingQuestion: pageData, delegate: self)
        stackView.addArrangedSubview(questionPicker)
        
        // Bottom View
        self.view.addSubview(self.confirmButtonView)
        self.confirmButtonView.autoPinEdgesToSuperviewSafeArea(with: .zero, excludingEdge: .top)
        self.confirmButtonView.autoPinEdge(.top, to: .bottom, of: self.scrollView)
        
        self.updateConfirmButton()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.secondary(hidden: false).style)
        self.addCustomBackButton()
    }
    
    // MARK: - Actions
    
    @objc private func confirmButtonPressed() {
        guard let answer = self.answer else {
            assertionFailure("Missing selected possible answer")
            return
        }
        let result = ProfilingResult(profilingQuestion: self.pageData, answer: answer)
        self.coordinator.onQuestionAnsweredSuccess(result: result)
    }
    
    // MARK: - Private Methods
    
    private func updateConfirmButton() {
        self.confirmButtonView.setButtonEnabled(enabled: self.answer != nil)
    }
}

extension ProfilingQuestionViewController: ProfilingQuestionProtocol {
    
    func answerDidChange(_ profilingQuestion: ProfilingQuestion, answer: Any) {
        print("SurveyQuestionViewController - Answer Did Change: \(answer)")
        self.answer = answer
    }
}
