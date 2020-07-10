//
//  BooleanQuestionsViewController.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 22/05/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import Foundation
import PureLayout

protocol BooleanQuestionsCoordinator {
    func onBooleanQuestionsSubmit(answers: [Answer])
}

public class BooleanQuestionsViewController: UIViewController {
    
    private var items: [Answer]
    private let coordinator: BooleanQuestionsCoordinator
    
    lazy private var tableView: UITableView = {
        let tableView = UITableView()
        tableView.dataSource = self
        tableView.registerCellsWithClass(QuestionBooleanTableViewCell.self)
        tableView.tableFooterView = UIView()
        tableView.contentInsetAdjustmentBehavior = .never
        tableView.estimatedRowHeight = 130.0
        tableView.backgroundColor = .clear
        return tableView
    }()
    
    private lazy var confirmButtonView: GenericButtonView = {
        let view = GenericButtonView(withImageStyleCategory: .secondaryBackground)
        view.addTarget(target: self, action: #selector(self.confirmButtonPressed))
        return view
    }()
    
    init(withQuestions questions: [Question], coordinator: BooleanQuestionsCoordinator) {
        self.items = questions.map { Answer(question: $0, currentAnswer: nil) }
        self.coordinator = coordinator
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = ColorPalette.color(withType: .secondary)
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        self.view.addSubview(stackView)
        stackView.autoPinEdgesToSuperviewSafeArea()
        
        stackView.addArrangedSubview(self.tableView)
        stackView.addArrangedSubview(self.confirmButtonView)
        
        self.tableView.reloadData()
        self.updateConfirmButton()
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.secondary(hidden: false).style)
        self.addCustomBackButton()
        self.addOnboardingAbortButton(withColor: ColorPalette.color(withType: .primary))
    }
    
    // MARK: Actions
    
    @objc private func confirmButtonPressed() {
        self.coordinator.onBooleanQuestionsSubmit(answers: self.items)
    }
    
    // MARK: Private Methods
    
    private func updateItem(questionIdentifier: String, answerIdentifier: String) {
        guard let itemIndex = self.items.firstIndex(where: { $0.question.id == questionIdentifier }) else {
            assertionFailure("Cannot find item with id: '\(questionIdentifier)'")
            return
        }
        var item = self.items[itemIndex]
        guard let answerIndex = item.question.possibleAnswers.firstIndex(where: { $0.id == answerIdentifier }) else {
            assertionFailure("Cannot find possibile answer with id: '\(answerIdentifier)', in question: \(item)")
            return
        }
        item.currentAnswer = item.question.possibleAnswers[answerIndex]
        self.items[itemIndex] = item
        self.tableView.reloadData()
        self.updateConfirmButton()
    }
    
    private func updateConfirmButton() {
        let buttonEnabled = self.items.allSatisfy({ $0.currentAnswer != nil })
        self.confirmButtonView.setButtonEnabled(enabled: buttonEnabled)
    }
}

extension BooleanQuestionsViewController: UITableViewDataSource {
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.items.count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCellOfType(type: QuestionBooleanTableViewCell.self, forIndexPath: indexPath) else {
            assertionFailure("Missing expected cell")
            return UITableViewCell()
        }
        guard indexPath.row < self.items.count else {
            assertionFailure("Unexpected row")
            return UITableViewCell()
        }
        let item = self.items[indexPath.row]
        cell.display(data: item,
                     answerPressedCallback: { [weak self] answerIdentifier in
                        self?.updateItem(questionIdentifier: item.question.id, answerIdentifier: answerIdentifier)
        })
        return cell
    }
}
