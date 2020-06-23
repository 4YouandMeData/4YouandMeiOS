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
    func onBooleanQuestionsSuccess()
    func onBooleanQuestionsFailure()
}

public class BooleanQuestionsViewController: UIViewController {
    
    private let questions: [Question]
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
    
    private var items: [QuestionBooleanDisplayData] = []
    
    init(withQuestions questions: [Question], coordinator: BooleanQuestionsCoordinator) {
        self.questions = questions
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
        
        self.items = self.questions.compactMap { $0.questionBooleanData }
        
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
        if self.validateAnswers() {
            self.coordinator.onBooleanQuestionsSuccess()
        } else {
            self.coordinator.onBooleanQuestionsFailure()
        }
    }
    
    // MARK: Private Methods
    
    private func updateItem(identifier: String, answerA: Bool) {
        guard let itemIndex = self.items.firstIndex(where: { $0.identifier == identifier }) else {
            assertionFailure("Cannot find item with id: '\(identifier)'")
            return
        }
        var item = self.items[itemIndex]
        item.answerAisActive = answerA
        self.items[itemIndex] = item
        self.tableView.reloadData()
        self.updateConfirmButton()
    }
    
    private func updateConfirmButton() {
        let buttonEnabled = self.items.allSatisfy({ $0.answerAisActive != nil })
        self.confirmButtonView.setButtonEnabled(enabled: buttonEnabled)
    }
    
    private func validateAnswers() -> Bool {
        return self.items.allSatisfy { question in
            if let correctAnswerA = question.correctAnswerA {
                return question.answerAisActive == correctAnswerA
            } else {
                return true
            }
        }
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
                     answerPressedCallback: { [weak self] answerA in
                        self?.updateItem(identifier: item.identifier,
                                         answerA: answerA)
        })
        return cell
    }
}

fileprivate extension Question {
    var questionBooleanData: QuestionBooleanDisplayData? {
        guard self.possibleAnswers.count >= 2 else {
            return nil
        }
        let answerA = self.possibleAnswers[0]
        let answerB = self.possibleAnswers[1]
        return QuestionBooleanDisplayData(identifier: self.id,
                                         question: self.text,
                                         answerA: answerA.text,
                                         answerB: answerB.text,
                                         correctAnswerA: answerA.correct,
                                         answerAisActive: nil)
    }
}
