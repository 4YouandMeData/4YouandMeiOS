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
    private let reflectionCoordinator: ReflectionSectionCoordinator?
        
    public fileprivate(set) var standardColor: UIColor = ColorPalette.color(withType: .primaryText)
    public fileprivate(set) var errorColor: UIColor = ColorPalette.color(withType: .primaryText)
    public fileprivate(set) var inactiveColor: UIColor = UIColor.init(hexString: "#A2A2A2")!
    
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

        stackView.addLabel(withText: StringsProvider.string(forKey: .diaryNoteCreateTextTitle),
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
    
    private lazy var textView: UITextView = {
        
        // Text View
        let textView = UITextView()
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 8
        textView.isScrollEnabled = true
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
        label.text = StringsProvider.string(forKey: .diaryNotePlaceholder)
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
        buttonView.setButtonText(StringsProvider.string(forKey: .diaryNoteCreateTextSave))
        buttonView.addTarget(target: self, action: #selector(self.editButtonPressed))
        
        return buttonView
    }()
    
    private var storage: CacheService
    private var diaryNote: DiaryNoteItem?
    private let maxCharacters: Int = 2500
    private let isEditMode: Bool
    private let isFromChart: Bool
    
    init(withDataPoint dataPoint: DiaryNoteItem?,
         isEditMode: Bool,
         isFromChart: Bool,
         reflectionCoordinator: ReflectionSectionCoordinator?) {
        self.navigator = Services.shared.navigator
        self.repository = Services.shared.repository
        self.storage = Services.shared.storageServices
        self.analytics = Services.shared.analytics
        self.diaryNote = dataPoint
        self.isEditMode = isEditMode
        self.isFromChart = isFromChart
        self.reflectionCoordinator = reflectionCoordinator
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        print("DiaryNoteTextViewController - deinit")
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = ColorPalette.color(withType: .secondary)
        
        // Main Stack View
        let stackView = UIStackView.create(withAxis: .vertical, spacing: 16.0)
        self.view.addSubview(stackView)
        stackView.autoPinEdges(toSuperviewMarginsExcludingEdge: .bottom)
        stackView.addArrangedSubview(self.headerView)
        
        let containerView = UIStackView.create(withAxis: .vertical, spacing: 16.0)
        self.view.addSubview(containerView)
        
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
        containerView.addArrangedSubview(containerTextView)
        containerTextView.autoPinEdge(.top, to: .bottom, of: self.headerView, withOffset: 16.0)
        
        containerView.addBlankSpace(space: 60.0)
        
        // Footer
        self.view.addSubview(self.footerView)
        footerView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets.zero, excludingEdge: .top)
        containerView.autoPinEdge(.top, to: .bottom, of: self.headerView)
        containerView.autoPinEdge(.leading, to: .leading, of: self.view)
        containerView.autoPinEdge(.trailing, to: .trailing, of: self.view)
        containerView.autoPinEdge(.bottom, to: .top, of: self.footerView)
        
        // Placeholder label
        self.textView.addSubview(self.placeholderLabel)
        self.placeholderLabel.isHidden = !textView.text.isEmpty
        self.placeholderLabel.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: CGFloat(self.textView.font!.pointSize/2),
                                                                              left: 5,
                                                                              bottom: 10,
                                                                              right: 10))
        
        self.pageState.subscribe(onNext: { [weak self] newPageState in
            guard let self = self else { return }
            self.updateNextButton(pageState: newPageState)
            self.updateTextFields(pageState: newPageState)
            self.view.endEditing(true)
            // Disable confirm button initially in edit if no text
            if newPageState == .edit {
                let hasText = !(self.textView.text.isEmpty)
                self.footerView.setButtonEnabled(enabled: hasText)
            }
        }).disposed(by: self.disposeBag)
        
        self.loadNote()
        
        self.addObservers()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.primary(hidden: true).style)
    }
    
    private func addObservers() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyboardWillChangeFrame(_:)),
                                               name: UIResponder.keyboardWillChangeFrameNotification,
                                               object: nil)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyboardWillHide(_:)),
                                               name: UIResponder.keyboardWillHideNotification,
                                               object: nil)
    }
    
    // MARK: - Actions
    
    @objc private func keyboardWillChangeFrame(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval else { return }

        let keyboardHeight = view.convert(keyboardFrame, from: nil).intersection(view.bounds).height

        UIView.animate(withDuration: duration) {
            self.textView.contentInset.bottom = keyboardHeight
            self.textView.verticalScrollIndicatorInsets.bottom = keyboardHeight
        }
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval else { return }

        UIView.animate(withDuration: duration) {
            self.textView.contentInset.bottom = 0
            self.textView.verticalScrollIndicatorInsets.bottom = 0
        }
    }
    
    @objc private func closeButtonPressed() {
        self.genericCloseButtonPressed(completion: {
            self.navigator.switchToDiaryTab(presenter: self)
        })
    }
    
    @objc private func editButtonPressed() {
        self.pageState.accept(.edit)
    }
    
    @objc private func confirmButtonPressed() {
        
        if isEditMode {
            if let diaryNote, self.diaryNote != nil {
                self.repository.updateDiaryNoteText(diaryNote: diaryNote)
                    .addProgress()
                    .subscribe(onSuccess: { [weak self] in
                        guard let self = self else { return }
                        self.closeButtonPressed()
                    }, onFailure: { [weak self] error in
                        guard let self = self else { return }
                        self.navigator.handleError(error: error, presenter: self)
                    }).disposed(by: self.disposeBag)
                self.pageState.accept(.read)
            }
                
        } else {
            if let diaryNote, self.diaryNote?.diaryNoteable != nil {
                self.repository.sendDiaryNoteText(diaryNote: diaryNote, fromChart: true)
                    .addProgress()
                    .subscribe(onSuccess: { [weak self] diaryNote in
                        guard let self = self else { return }
                        guard let coordinator = self.reflectionCoordinator else {
                            return self.closeButtonPressed()
                        }
                        coordinator.onReflectionCreated(presenter: self, reflectionType: .text, diaryNote: diaryNote)
                    }, onFailure: { [weak self] error in
                        guard let self = self else { return }
                        self.navigator.handleError(error: error, presenter: self)
                    }).disposed(by: self.disposeBag)
                self.pageState.accept(.read)
            } else {
                let newDiaryNote = DiaryNoteItem(diaryNoteId: self.diaryNote?.diaryNoteId.string(withFormat: dateTimeFormat),
                                                 body: self.textView.text,
                                                 interval: nil,
                                                 diaryNoteable: nil)

                self.repository.sendDiaryNoteText(diaryNote: newDiaryNote, fromChart: false)
                    .addProgress()
                    .subscribe(onSuccess: { [weak self] diaryNote in
                        guard let self = self else { return }
                        guard let coordinator = self.reflectionCoordinator else {
                            return self.closeButtonPressed()
                        }
                        coordinator.onReflectionCreated(presenter: self, reflectionType: .text, diaryNote: diaryNote)
                    }, onFailure: { [weak self] error in
                        guard let self = self else { return }
                        self.navigator.handleError(error: error, presenter: self)
                    }).disposed(by: self.disposeBag)
                self.pageState.accept(.read)
            }
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
            button.setButtonText(StringsProvider.string(forKey: .diaryNoteCreateTextConfirm))
            button.addTarget(target: self, action: #selector(self.confirmButtonPressed))
        case .read:
            button.setButtonText(StringsProvider.string(forKey: .diaryNoteCreateTextEdit))
            button.addTarget(target: self, action: #selector(self.editButtonPressed))
        }
    }

    private func updateTextFields(pageState: PageState) {
        let textView = self.textView
        self.placeholderLabel.isHidden = !textView.text.isEmpty
        switch pageState {
        case .edit:
            textView.isEditable = true
            textView.isUserInteractionEnabled = true
            textView.textColor = self.standardColor
        case .read:
            textView.isEditable = false
            textView.isUserInteractionEnabled = false
            textView.textColor = self.inactiveColor
        }
    }
    
    private func loadNote() {
        
        guard self.reflectionCoordinator != nil else {
            
            guard let dataPoint = self.diaryNote, self.isEditMode == true else {
                self.pageState.accept(.edit)
                return
            }
            
            self.repository.getDiaryNoteText(noteID: dataPoint.id)
                .addProgress()
                .subscribe(onSuccess: { [weak self] diaryNoteText in
                    guard let self = self else { return }
                    self.diaryNote = diaryNoteText
                    self.textView.text = diaryNoteText.body
                    self.updateTextFields(pageState: self.pageState.value)
                }, onFailure: { [weak self] error in
                    guard let self = self else { return }
                    self.navigator.handleError(error: error, presenter: self)
                }).disposed(by: self.disposeBag)
            
            return
        }
        
        self.pageState.accept(.edit)
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
        
        // Enable/disable confirm button when editing
        if pageState.value == .edit {
            let enabled = !textView.text.isEmpty
            footerView.setButtonEnabled(enabled: enabled)
        }
    }
}
