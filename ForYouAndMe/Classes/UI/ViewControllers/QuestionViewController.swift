//
//  QuestionViewController.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 11/06/2020.
//

import Foundation
import PureLayout
import TPKeyboardAvoiding

protocol QuestionViewCoordinator {
    func onQuestionAnsweredSuccess(answer: Answer)
}

class QuestionViewController: UIViewController {
    
    private let question: Question
    private let coordinator: QuestionViewCoordinator
    private var otherAnswers: [String: String] = [:]
    private var footerView: QuestionFooterView?
    
    lazy private var tableView: TPKeyboardAvoidingTableView = {
        let tableView = TPKeyboardAvoidingTableView()
        tableView.dataSource = self
        tableView.registerCellsWithClass(PossibleAnswerTableViewCell.self)
        tableView.tableFooterView = UIView()
        tableView.contentInsetAdjustmentBehavior = .never
        tableView.estimatedRowHeight = 130.0
        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        tableView.keyboardDismissMode = .interactive
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
        
        if ProjectInfo.StudyId.lowercased() == "saba" {
            let footer = QuestionFooterView()
            self.footerView = footer
            footer.textFieldView.delegate = self
            self.tableView.tableFooterView = footer
        }
        
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
        self.tableView.sizeFooterToFit()
    }
    
    // MARK: Actions
    
    @objc private func confirmButtonPressed() {
        guard let selected = selectedPossibleAnswer else {
            assertionFailure("Missing selected possible answer")
            return
        }

        let answerText: String?
        if selected.isOther {
            answerText = self.otherAnswers[selected.id]
        } else if ProjectInfo.StudyId.lowercased() == "saba" {
            answerText = self.footerView?.textFieldView.text
        } else {
            answerText = nil
        }

        let answer = Answer(
            question: self.question,
            possibleAnswer: selected,
            answerText: answerText
        )

        self.coordinator.onQuestionAnsweredSuccess(answer: answer)
    }
    
    // MARK: Private Methods
    
    private func updateConfirmButton() {
        let isSaba = ProjectInfo.StudyId.lowercased() == "saba"
        let hasSelection = self.selectedPossibleAnswer != nil
        let footerTextValid = self.footerView?.textFieldView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false

        let enabled = isSaba ? (hasSelection && footerTextValid) : hasSelection
        self.confirmButtonView.setButtonEnabled(enabled: enabled)
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
                     isOther: item.isOther,
                     otherText: self.otherAnswers[item.id],
                     answerPressedCallback: { [weak self] in
            guard let self = self else { return }
            
        if ProjectInfo.StudyId.lowercased() == "saba" {
                self.footerView?.textFieldView.text = ""
                self.footerView?.textFieldView.resignFirstResponder()
                self.updateConfirmButton()
            }
            
            self.selectedPossibleAnswer = item
            
            if ProjectInfo.StudyId.lowercased() == "saba" {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    if let footer = self.footerView {
                        let footerRect = self.tableView.convert(footer.frame, from: footer.superview)
                        self.tableView.scrollRectToVisible(footerRect, animated: true)
                    }
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
                }
            }
        },
                     otherAnswerChangedCallback: { [weak self] newText in
            self?.otherAnswers[item.id] = newText
        })
        return cell
    }
}

extension QuestionViewController: GenericTextFieldViewDelegate {
    func genericTextFieldDidChange(textField: GenericTextFieldView) {
        self.updateConfirmButton()
    }

    func genericTextFieldShouldReturn(textField: GenericTextFieldView) -> Bool {
        self.view.endEditing(true)
        return true
    }
}
