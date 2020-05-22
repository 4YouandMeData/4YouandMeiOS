//
//  ScreeningQuestionsViewController.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 22/05/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import Foundation
import PureLayout

public class ScreeningQuestionsViewController: UIViewController {
    
    private let navigator: AppNavigator
    
    lazy private var tableView: UITableView = {
        let tableView = UITableView()
        tableView.dataSource = self
        tableView.registerCellsWithClass(QuestionBinaryTableViewCell.self)
        tableView.tableFooterView = UIView()
        tableView.contentInsetAdjustmentBehavior = .never
        tableView.estimatedRowHeight = 130.0
        return tableView
    }()
    
    private lazy var confirmButtonView: GenericButtonView = {
        let view = GenericButtonView(withImageStyleCategory: .secondaryBackground)
        view.button.addTarget(self, action: #selector(self.confirmButtonPressed), for: .touchUpInside)
        return view
    }()
    
    private var items: [QuestionBinary] = []
    
    init() {
        self.navigator = Services.shared.navigator
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = ColorPalette.color(withType: .secondary)
        
        // TODO: Add screening questions
        self.items.append(QuestionBinary(identifier: "1",
                                             question: "Are you pregnant",
                                             answerA: "Yes",
                                             answerB: "No",
                                             answerAisActive: nil,
                                             correctAnswerA: true))
        self.items.append(QuestionBinary(identifier: "2",
                                             question: "Are you in your first trimester\n(less than 14 weeks)?",
                                             answerA: "Yes",
                                             answerB: "No",
                                             answerAisActive: nil,
                                             correctAnswerA: true))
        self.items.append(QuestionBinary(identifier: "3",
                                         question: "Are you currently or are you planning to be a patient of the Mount Sinai Health System?",
                                         answerA: "Yes",
                                         answerB: "No",
                                         answerAisActive: nil,
                                         correctAnswerA: false))
        self.items.append(QuestionBinary(identifier: "4",
                                         question: "Are you over 18 years old?",
                                         answerA: "Yes",
                                         answerB: "No",
                                         answerAisActive: nil,
                                         correctAnswerA: true))
        self.items.append(QuestionBinary(identifier: "5",
                                         question: "Have you ever climbed Mount Doom, riding a Gallimimus, using a lightsaber to defend yourself against Chaos Space Marines' volley fire? Of course, returning home without the help of the Great Eagles... the correct answer for this question is 'Yes'. Sorry :)",
                                         answerA: "Yes",
                                         answerB: "No",
                                         answerAisActive: nil,
                                         correctAnswerA: true))
        self.items.append(QuestionBinary(identifier: "6",
                                         question: "Do you read and write in English?",
                                         answerA: "Yes",
                                         answerB: "No",
                                         answerAisActive: nil,
                                         correctAnswerA: true))
        self.items.append(QuestionBinary(identifier: "7",
                                         question: "Do any of these apply to you?\n - in prison\n - No permanent address\n - Planning to terminate pregnancy",
                                         answerA: "Yes",
                                         answerB: "No",
                                         answerAisActive: nil,
                                         correctAnswerA: false))
        
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
        
        self.navigationController?.navigationBar.apply(style: NavigationBarStyles.secondaryStyle)
        self.addCustomBackButton()
        self.addOnboardingAbortButton(withColor: ColorPalette.color(withType: .primary))
    }
    
    // MARK: Actions
    
    @objc private func confirmButtonPressed() {
        if self.validateAnswers() {
            // TODO: Navigate to success view
            print("TODO: Navigate to success view")
        } else {
            // TODO: Navigate to failure view
            print("TODO: Navigate to failure view")
        }
    }
    
    // MARK: Private Methods
    
    private func updateItem(identifier: String, answerA: Bool) {
        guard let itemIndex = self.items.firstIndex(where: { $0.identifier == identifier }) else {
            assertionFailure("Cannot find item with id: '\(identifier)'")
            return
        }
        let item = self.items[itemIndex]
        let updatedItem = QuestionBinary(identifier: item.identifier,
                                         question: item.question,
                                         answerA: item.answerA,
                                         answerB: item.answerB,
                                         answerAisActive: answerA,
                                         correctAnswerA: item.correctAnswerA)
        self.items[itemIndex] = updatedItem
        self.tableView.reloadData()
        self.updateConfirmButton()
    }
    
    private func updateConfirmButton() {
        let buttonEnabled = self.items.allSatisfy({ $0.answerAisActive != nil })
        self.confirmButtonView.button.isEnabled = buttonEnabled
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

extension ScreeningQuestionsViewController: UITableViewDataSource {
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.items.count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCellOfType(type: QuestionBinaryTableViewCell.self, forIndexPath: indexPath) else {
            assertionFailure("Missing expected cell")
            return UITableViewCell()
        }
        guard indexPath.row < self.items.count else {
            assertionFailure("Unexpected row")
            return UITableViewCell()
        }
        let item = self.items[indexPath.row]
        cell.display(questionBinary: item,
                     answerPressedCallback: { [weak self] answerA in
                        self?.updateItem(identifier: item.identifier,
                                         answerA: answerA)
        })
        return cell
    }
}
