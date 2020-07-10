//
//  QuestionViewController.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 11/06/2020.
//

import Foundation
import PureLayout

protocol QuestionViewCoordinator {
    func onQuestionAnsweredSuccess(answer: Answer)
}

class QuestionViewController: UIViewController {
    
    private let question: Question
    private let coordinator: QuestionViewCoordinator
    
    lazy private var tableView: UITableView = {
        let tableView = UITableView()
        tableView.dataSource = self
        tableView.registerCellsWithClass(PossibleAnswerTableViewCell.self)
        tableView.tableFooterView = UIView()
        tableView.contentInsetAdjustmentBehavior = .never
        tableView.estimatedRowHeight = 130.0
        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        return tableView
    }()
    
    private lazy var confirmButtonView: GenericButtonView = {
        let view = GenericButtonView(withImageStyleCategory: .primaryBackground)
        view.addTarget(target: self, action: #selector(self.confirmButtonPressed))
        return view
    }()
    
    private var items: [PossibleAnswer] = []
    
    private var selectedPossibleAnswer: PossibleAnswer? {
        didSet {
            self.tableView.reloadData()
            self.updateConfirmButton()
        }
    }
    
    init(withQuestion question: Question, coordinator: QuestionViewCoordinator) {
        self.question = question
        self.coordinator = coordinator
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.addGradientView(GradientView(type: .primaryBackground))
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        self.view.addSubview(stackView)
        stackView.autoPinEdgesToSuperviewSafeArea()
        
        stackView.addArrangedSubview(self.tableView)
        stackView.addArrangedSubview(self.confirmButtonView)
        
        // Question
        let questionLabel = UILabel()
        questionLabel.attributedText = NSAttributedString.create(withText: self.question.text,
                                                                 fontStyle: .title,
                                                                 colorType: .secondaryText,
                                                                 textAlignment: .left)
        questionLabel.numberOfLines = 0
        let questionLabelContainerView = UIView()
        questionLabelContainerView.addSubview(questionLabel)
        questionLabel.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 40.0,
                                                                      left: Constants.Style.DefaultHorizontalMargins,
                                                                      bottom: 40.0,
                                                                      right: Constants.Style.DefaultHorizontalMargins))
        self.tableView.tableHeaderView = questionLabelContainerView
        
        self.items = self.question.possibleAnswers
        
        self.tableView.reloadData()
        self.updateConfirmButton()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.primary(hidden: false).style)
        self.addOnboardingAbortButton(withColor: ColorPalette.color(withType: .secondaryText))
        self.navigationItem.hidesBackButton = true
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        self.tableView.sizeHeaderToFit()
    }
    
    // MARK: Actions
    
    @objc private func confirmButtonPressed() {
        guard let selectedPossibleAnswer = selectedPossibleAnswer else {
            assertionFailure("Missing selected possible answer")
            return
        }
        self.coordinator.onQuestionAnsweredSuccess(answer: Answer(question: self.question, possibleAnswer: selectedPossibleAnswer))
    }
    
    // MARK: Private Methods
    
    private func updateConfirmButton() {
        self.confirmButtonView.setButtonEnabled(enabled: self.selectedPossibleAnswer != nil)
    }
}

extension QuestionViewController: UITableViewDataSource {
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.items.count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCellOfType(type: PossibleAnswerTableViewCell.self, forIndexPath: indexPath) else {
            assertionFailure("Missing expected cell")
            return UITableViewCell()
        }
        guard indexPath.row < self.items.count else {
            assertionFailure("Unexpected row")
            return UITableViewCell()
        }
        let item = self.items[indexPath.row]
        cell.display(data: item,
                     isSelected: self.selectedPossibleAnswer?.id == item.id,
                     answerPressedCallback: { [weak self] in
                        self?.selectedPossibleAnswer = item
        })
        return cell
    }
}
