//
//  DiaryNoteTextViewController.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 03/12/24.
//

import UIKit
import RxSwift
import RxCocoa

class DiaryNoteTextViewController: UIViewController {
    
    fileprivate enum PageState { case read, edit }
    
    private let pageState: BehaviorRelay<PageState> = BehaviorRelay<PageState>(value: .read)
    private let navigator: AppNavigator
    private let repository: Repository
    private let analytics: AnalyticsService
        
    public fileprivate(set) var standardColor: UIColor = ColorPalette.color(withType: .primaryText)
    public fileprivate(set) var errorColor: UIColor = ColorPalette.color(withType: .primaryText)
    public fileprivate(set) var inactiveColor: UIColor = ColorPalette.color(withType: .fourthText)
    
    private let disposeBag = DisposeBag()
    
    private lazy var closeButton: UIButton = {
        let button = UIButton()
        button.setImage(ImagePalette.templateImage(withName: .backButtonNavigation), for: .normal)
        button.tintColor = ColorPalette.color(withType: .primaryText)
        button.autoSetDimension(.width, toSize: 32)
        button.imageView?.contentMode = .scaleAspectFit
        button.addTarget(self, action: #selector(self.closeButtonPressed), for: .touchUpInside)
        return button
    }()
    
    private lazy var headerView: UIView = {
        let containerView = UIView()
        
        let stackView = UIStackView.create(withAxis: .vertical, spacing: 8.0)
        
        // Close button
        let closeButtonContainerView = UIView()
        closeButtonContainerView.addSubview(self.closeButton)
        self.closeButton.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .trailing)
        stackView.addArrangedSubview(closeButtonContainerView)

        stackView.addLabel(withText: "Text Note",
                           fontStyle: .title,
                           colorType: .primaryText)
        
        stackView.addLineSeparator(lineColor: ColorPalette.color(withType: .secondaryMenu), space: 0, isVertical: false)
        
        containerView.addSubview(stackView)
        stackView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 25.0,
                                                                     left: Constants.Style.DefaultHorizontalMargins/2,
                                                                     bottom: 0,
                                                                     right: Constants.Style.DefaultHorizontalMargins/2))
        return containerView
    }()
    
    public lazy var textField: UITextField = {
        let textField = UITextField()
        textField.textColor = self.standardColor
        textField.tintColor = self.standardColor
        textField.font = FontPalette.fontStyleData(forStyle: .paragraph).font
        textField.delegate = self
        textField.borderStyle = .roundedRect
        textField.placeholder = "Add title here"
        return textField
    }()
    
    private lazy var textView: UITextView = {
        
        // Text View
        let textView = UITextView()
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 8
        textView.typingAttributes = [.foregroundColor: ColorPalette.color(withType: .primaryText),
                                     .font: FontPalette.fontStyleData(forStyle: .header3).font,
                                     .paragraphStyle: style]
        textView.delegate = self
        textView.layer.borderWidth = 1
        textView.tintColor = ColorPalette.color(withType: .primary)
        textView.layer.borderColor = ColorPalette.color(withType: .inactive).cgColor
        textView.layer.cornerRadius = 8
        textView.clipsToBounds = true
        
        // Toolbar
        let toolBar = UIToolbar()
        toolBar.barStyle = .default
        toolBar.isTranslucent = true
        toolBar.tintColor = ColorPalette.color(withType: .primary)
        toolBar.sizeToFit()
        
        let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(self.doneButtonPressed))
        let spaceButton = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        
        toolBar.setItems([spaceButton, doneButton], animated: false)
        textView.inputAccessoryView = toolBar
        
        return textView
    }()
    
    private lazy var placeholderLabel: UILabel = {
        let label = UILabel()
        label.text = "Insert your note here"
        label.font = FontPalette.fontStyleData(forStyle: .paragraph).font
        label.textColor = ColorPalette.color(withType: .inactive)
        label.sizeToFit()
        return label
    }()
    
    private var limitLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .right
        label.font = FontPalette.fontStyleData(forStyle: .header3).font
        label.textColor = ColorPalette.color(withType: .inactive)
        return label
    }()
    
    private lazy var footerView: GenericButtonView = {
        
        let buttonView = GenericButtonView(withTextStyleCategory: .secondaryBackground())
        buttonView.setButtonText("Save Note")
        buttonView.addTarget(target: self, action: #selector(self.editButtonPressed))
        
        return buttonView
    }()
    
    private var storage: CacheService
    private let dataPointID: String?
    private var diaryNote: DiaryNoteItem? = nil
    private let maxCharacters: Int = 500
    
    init(withDataPointID dataPointID: String?) {
        self.navigator = Services.shared.navigator
        self.repository = Services.shared.repository
        self.storage = Services.shared.storageServices
        self.analytics = Services.shared.analytics
        self.dataPointID = dataPointID
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        print("DiaryNoteTextViewController - deinit")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = ColorPalette.color(withType: .secondary)
        
        // Main Stack View
        let stackView = UIStackView.create(withAxis: .vertical, spacing: 16.0)
        self.view.addSubview(stackView)
        stackView.autoPinEdgesToSuperviewEdges()
        stackView.addArrangedSubview(self.headerView)
        
        // TextField
        let containerTextField = UIView()
        containerTextField.addSubview(self.textField)
        stackView.addArrangedSubview(containerTextField)
        self.textField.autoSetDimension(.height, toSize: 44.0)
        self.textField.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 0,
                                                                      left: 12.0,
                                                                      bottom: 0,
                                                                      right: 12.0))
        
        let containerTextView = UIView()
        containerTextView.addSubview(self.textView)
        self.textView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 0,
                                                                      left: 12.0,
                                                                      bottom: 0,
                                                                      right: 12.0))
        // Limit label
        containerTextView.addSubview(self.limitLabel)
        self.limitLabel.autoPinEdge(.top, to: .bottom, of: self.textView)
        self.limitLabel.autoPinEdge(.right, to: .right, of: self.textView)
        self.limitLabel.autoPinEdge(.left, to: .left, of: self.textView)
        self.limitLabel.text = "\(self.textView.text.count) / \(self.maxCharacters)"
        stackView.addArrangedSubview(containerTextView)
        containerTextView.autoPinEdge(.top, to: .bottom, of: self.textField, withOffset: 16.0)
        
        stackView.addBlankSpace(space: 60.0)
        
        // Footer
        let containerFooterView = UIView()
        containerFooterView.addSubview(self.footerView)
        footerView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets.zero)
        stackView.addArrangedSubview(containerFooterView)
                
        // Placeholder label
        self.textView.addSubview(self.placeholderLabel)
        self.placeholderLabel.isHidden = !textView.text.isEmpty
        self.placeholderLabel.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: CGFloat(self.textView.font!.pointSize/2),
                                                                              left: 5,
                                                                              bottom: 10,
                                                                              right: 10))
        
        self.pageState.subscribe(onNext: { [weak self] newPageState in
            self?.updateNextButton(pageState: newPageState)
            self?.updateTextFields(pageState: newPageState)
            self?.view.endEditing(true)
        }).disposed(by: self.disposeBag)
        
        self.loadNote()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.primary(hidden: true).style)
    }
    
    // MARK: - Actions
    
    @objc private func closeButtonPressed() {
        self.customBackButtonPressed()
    }
    
    @objc private func editButtonPressed() {
        self.pageState.accept(.edit)
    }
    
    @objc private func confirmButtonPressed() {
        if let diaryNote, self.diaryNote != nil {
            self.repository.updateDiaryNoteText(diaryNote: diaryNote)
                .addProgress()
                .subscribe(onSuccess: { [weak self] in
                    guard let self = self else { return }
                    self.navigationController?.popViewController(animated: true)
                }, onError: { [weak self] error in
                    guard let self = self else { return }
                    self.navigator.handleError(error: error, presenter: self)
                }).disposed(by: self.disposeBag)
            self.pageState.accept(.read)
        } else {
            let newDiaryNote = DiaryNoteItem.init(id: "0",
                                               type: "diary_note",
                                               diaryNoteId: self.dataPointID?.date(withFormat: "yyyy-MM-dd'T'HH:mm:ss'Z'") ?? NSDate.now,
                                               diaryNoteType: .text,
                                               title: self.textField.text,
                                               body: self.textView.text)

            self.repository.sendDiaryNoteText(diaryNote: newDiaryNote)
                .addProgress()
                .subscribe(onSuccess: { [weak self] in
                    guard let self = self else { return }
                    self.navigationController?.popViewController(animated: true)
                }, onError: { [weak self] error in
                    guard let self = self else { return }
                    self.navigator.handleError(error: error, presenter: self)
                }).disposed(by: self.disposeBag)
            self.pageState.accept(.read)
        }
    }
    
    @objc private func doneButtonPressed() {
        self.textView.resignFirstResponder()
    }
    
    // MARK: - Private Methods
    
    private func updateNextButton(pageState: PageState) {
        let button = self.footerView
        switch pageState {
        case .edit:
            button.setButtonText("Confirm")
            button.addTarget(target: self, action: #selector(self.confirmButtonPressed))
        case .read:
            button.setButtonText("Edit")
            button.addTarget(target: self, action: #selector(self.editButtonPressed))
        }
    }

    private func updateTextFields(pageState: PageState) {
        let textField = self.textField
        let textView = self.textView
        self.placeholderLabel.isHidden = !textView.text.isEmpty
        switch pageState {
        case .edit:
            textView.isEditable = true
            textView.isUserInteractionEnabled = true
            textView.textColor = self.standardColor
            textField.isUserInteractionEnabled = true
            textField.textColor = self.standardColor
        case .read:
            textView.isEditable = false
            textView.isUserInteractionEnabled = false
            textView.textColor = self.inactiveColor
            textField.isUserInteractionEnabled = false
            textField.textColor = self.inactiveColor
        }
    }
    
    private func loadNote() {
        guard let dataPointID = self.dataPointID else { return }
        
        self.repository.getDiaryNoteText(noteID: dataPointID)
            .addProgress()
            .subscribe(onSuccess: { [weak self] diaryNoteText in
                guard let self = self else { return }
                self.diaryNote = diaryNoteText
                self.textView.text = diaryNoteText.body
                self.textField.text = diaryNoteText.title
                self.updateTextFields(pageState: self.pageState.value)
            }, onError: { [weak self] error in
                guard let self = self else { return }
                self.navigator.handleError(error: error, presenter: self)
            }).disposed(by: self.disposeBag)
    }
}

extension DiaryNoteTextViewController: UITextViewDelegate {
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        self.placeholderLabel.isHidden = !textView.text.isEmpty
    }
    
    func textViewDidChange(_ textView: UITextView) {
        self.placeholderLabel.isHidden = !textView.text.isEmpty
        self.limitLabel.text = "\(textView.text.count) / \(self.maxCharacters)"
        if textView.text.count <= self.maxCharacters {
            textView.layer.borderColor = ColorPalette.color(withType: .inactive).cgColor
            self.limitLabel.textColor = ColorPalette.color(withType: .inactive)
            self.diaryNote?.body = textView.text
        } else {
            textView.layer.borderColor = UIColor.red.cgColor
            self.limitLabel.textColor = .red
        }
    }
}

extension DiaryNoteTextViewController: UITextFieldDelegate {

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let newString = textField.getNewString(forRange: range, replacementString: string)
        let returnKey = !(newString.count > self.maxCharacters)
        if returnKey {
            self.diaryNote?.title = newString
        }
        return returnKey

    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.view.endEditing(true)
    }
}
