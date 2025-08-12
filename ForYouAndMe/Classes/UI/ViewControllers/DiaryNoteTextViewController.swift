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
    private var selectedEmoji: EmojiItem?
    private var originalBody: String?
    private var wasJustCreatedHere: Bool = false

    private lazy var titleRow: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        stack.distribution = .equalSpacing
        return stack
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.attributedText = NSAttributedString.create(
            withText: StringsProvider.string(forKey: .diaryNoteCreateTextTitle),
            fontStyle: .title,
            color: ColorPalette.color(withType: .primaryText),
            textAlignment: .center
        )
        return label
    }()
    
    private var isChartLinkedNote: Bool {
        return isFromChart && (diaryNote?.diaryNoteable != nil)
    }
    
    private lazy var editButton: UIButton = {
        let button = UIButton()
        button.setImage(ImagePalette.image(withName: .editAudioNote), for: .normal)
        button.setTitle(StringsProvider.string(forKey: .diaryNoteCreateTextEdit), for: .normal)
        button.setTitleColor(ColorPalette.color(withType: .primaryText), for: .normal)
        button.backgroundColor = ColorPalette.color(withType: .inactive).applyAlpha(0.8)
        button.titleLabel?.font = FontPalette.fontStyleData(forStyle: .menu).font
        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: -4, bottom: 0, right: 4)
        button.contentEdgeInsets = UIEdgeInsets(top: 3, left: 8, bottom: 3, right: 8)
        button.layer.cornerRadius = 6.0
        button.clipsToBounds = true
        button.addTarget(self, action: #selector(editButtonPressed), for: .touchUpInside)
        return button
    }()
        
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
    
    private lazy var emojiButton: UIButton = {
        let button = UIButton()
        button.setImage(ImagePalette.image(withName: .emojiICon), for: .normal)
        button.tintColor = ColorPalette.color(withType: .primaryText)
        button.autoSetDimensions(to: CGSize(width: 24, height: 24))
        button.addTarget(self, action: #selector(emojiButtonTapped), for: .touchUpInside)
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

        let emptyView = UIView()
        emptyView.autoSetDimensions(to: CGSize(width: 24, height: 24))
        
        let category = self.categoryForEmoji(diaryNote: self.diaryNote)
        if !self.emojiItems(for: category).isEmpty,
           self.isEditMode {
            titleRow.addArrangedSubview(emptyView)
            titleRow.addArrangedSubview(titleLabel)
            titleRow.addArrangedSubview(emojiButton)
        } else {
            titleRow.addArrangedSubview(titleLabel)
        }
        stackView.addArrangedSubview(titleRow)
        
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
        
        let cancelButton = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(self.cancelEdit)
        )

        let doneButton = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(self.doneButtonPressed)
        )
        
        let spaceButton = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        
        toolBar.setItems([cancelButton, spaceButton, doneButton], animated: false)
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
        buttonView.addTarget(target: self, action: #selector(self.footerTapped))
        
        return buttonView
    }()
    
    private var cache: CacheService
    private var diaryNote: DiaryNoteItem?
    private let maxCharacters: Int = 5000
    private let isEditMode: Bool
    private let isFromChart: Bool
    
    init(withDataPoint dataPoint: DiaryNoteItem?,
         isEditMode: Bool,
         isFromChart: Bool,
         reflectionCoordinator: ReflectionSectionCoordinator?) {
        self.navigator = Services.shared.navigator
        self.repository = Services.shared.repository
        self.cache = Services.shared.storageServices
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
        containerTextView.addSubview(self.editButton)
        self.editButton.autoPinEdge(.bottom, to: .bottom, of: self.textView, withOffset: -8.0)
        self.editButton.autoPinEdge(.right, to: .right, of: self.textView, withOffset: -8.0)
        
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
        
        self.pageState
            .subscribe(onNext: { [weak self] newState in
                guard let self = self else { return }
                self.updateNextButton(pageState: newState)
                self.updateTextFields(pageState: newState)
                self.updateTitleRow()
                self.view.endEditing(true)

                let shouldShowEditButton = (self.diaryNote != nil && newState == .read)
                self.editButton.isHidden = !shouldShowEditButton
            })
            .disposed(by: self.disposeBag)
        
        if let emoji = self.diaryNote?.feedbackTags?.last {
            self.selectedEmoji = emoji
            self.emojiButton.setImage(nil, for: .normal)
            self.emojiButton.setTitle(emoji.tag, for: .normal)
            self.emojiButton.titleLabel?.font = UIFont.systemFont(ofSize: 22)
        }
        
        self.loadNote()
        self.updateTitleRow()
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
    
    @objc private func cancelEdit() {
        self.textView.text = self.originalBody
        self.placeholderLabel.isHidden = !(self.originalBody?.isEmpty ?? true)

        if self.diaryNote != nil {
            self.pageState.accept(.read)
        } else {
            self.pageState.accept(.edit)
        }
    }
    
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
    
    @objc private func footerTapped() {
        switch pageState.value {
        case .edit:
            self.doneButtonPressed()
        case .read:
            if isChartLinkedNote || wasJustCreatedHere {
                self.closeSelf()   // “Close” behavior
            } else {
                self.closeButtonPressed()
            }
        }
    }
    
    /// Close helper: dismiss or pop depending on presentation
    private func closeSelf() {
        // If embedded in a nav and it's modally presented with a single VC, dismiss the nav
        if let nav = self.navigationController {
            if nav.presentingViewController != nil, nav.viewControllers.count <= 1 {
                nav.dismiss(animated: true, completion: nil)
            } else {
                nav.popViewController(animated: true)
            }
        } else {
            self.dismiss(animated: true, completion: nil)
        }
    }
    
    @objc private func closeButtonPressed() {
        self.genericCloseButtonPressed(completion: {
            self.navigator.switchToDiaryTab(presenter: self)
        })
    }
    
    @objc private func editButtonPressed() {
        self.originalBody = self.textView.text
        self.pageState.accept(.edit)
        self.textView.becomeFirstResponder()
    }
    
    @objc private func doneButtonPressed() {
        self.textView.resignFirstResponder()

        // Update existing note
        if var diaryNote = self.diaryNote {
            diaryNote.body = self.textView.text

            // Case: update via send (when linked to a diaryNoteable)
            if diaryNote.diaryNoteable != nil {
                self.repository.sendDiaryNoteText(diaryNote: diaryNote, fromChart: true)
                    .addProgress()
                    .subscribe(onSuccess: { [weak self] savedNote in
                        guard let self = self else { return }
                        self.diaryNote = savedNote
                        self.pageState.accept(.read)
                    }, onFailure: { [weak self] error in
                        guard let self = self else { return }
                        self.navigator.handleError(error: error, presenter: self)
                    }).disposed(by: self.disposeBag)
            } else {
                // Case: normal update
                self.repository.updateDiaryNoteText(diaryNote: diaryNote)
                    .addProgress()
                    .subscribe(onSuccess: { [weak self] in
                        self?.diaryNote = diaryNote
                        self?.pageState.accept(.read)
                    }, onFailure: { [weak self] error in
                        guard let self = self else { return }
                        self.navigator.handleError(error: error, presenter: self)
                    }).disposed(by: self.disposeBag)
            }

        } else {
            // Case: create new note
            let newDiaryNote = DiaryNoteItem(
                diaryNoteId: nil,
                body: self.textView.text,
                interval: nil,
                diaryNoteable: nil
            )

            self.repository.sendDiaryNoteText(diaryNote: newDiaryNote, fromChart: false)
                .addProgress()
                .subscribe(onSuccess: { [weak self] savedNote in
                    guard let self = self else { return }
                    self.diaryNote = savedNote
                    self.wasJustCreatedHere = true
                    if let coordinator = self.reflectionCoordinator {
                        coordinator.onReflectionCreated(presenter: self, reflectionType: .text, diaryNote: savedNote)
                        self.pageState.accept(.read)
                    } else {
                        self.textView.text = savedNote.body
                        self.placeholderLabel.isHidden = ((savedNote.body?.isEmpty) == nil)
                        self.pageState.accept(.read)
                    }
                }, onFailure: { [weak self] error in
                    guard let self = self else { return }
                    self.navigator.handleError(error: error, presenter: self)
                }).disposed(by: self.disposeBag)
        }
    }

    @objc private func emojiButtonTapped() {
        
        let category = self.categoryForEmoji(diaryNote: self.diaryNote)
        let emojiItems = self.emojiItems(for: category)
        let emojiVC = EmojiPopupViewController(emojis: emojiItems,
                                               selected: self.selectedEmoji) { [weak self] selectedEmoji in
            guard let self = self, let emoji = selectedEmoji else { return }
            guard var diaryNote = self.diaryNote else { return }

            self.selectedEmoji = emoji
            diaryNote.feedbackTags?.append(emoji)

            self.emojiButton.setImage(nil, for: .normal)
            self.emojiButton.setTitle(emoji.tag, for: .normal)
            self.emojiButton.titleLabel?.font = UIFont.systemFont(ofSize: 22)
            
            self.repository.updateDiaryNoteText(diaryNote: diaryNote)
                .addProgress()
                .subscribe(onSuccess: { },
                           onFailure: { [weak self] error in
                    guard let self = self else { return }
                    self.navigator.handleError(error: error, presenter: self)
                }).disposed(by: self.disposeBag)
        }
        
        emojiVC.modalPresentationStyle = .overCurrentContext
        emojiVC.modalTransitionStyle = .crossDissolve
        self.present(emojiVC, animated: true)
    }
    
    // MARK: - Private Methods
    private func updateTitleRow() {
        // Clear previous subviews
        self.titleRow.arrangedSubviews.forEach {
            self.titleRow.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        let category   = self.categoryForEmoji(diaryNote: self.diaryNote)
        let hasEmojis  = !self.emojiItems(for: category).isEmpty
        let noteExists = (self.diaryNote != nil)

        // A chart–linked note: created from chart and has a noteable
        let isChartLinkedNote = self.isFromChart && (self.diaryNote?.diaryNoteable != nil)

        // Hide back when a chart-linked note has been created and we are in READ
        let hideBackInHeader = (self.pageState.value == .read) && (isChartLinkedNote || wasJustCreatedHere)

        // Show emoji when the note exists and we're in READ state,
        //  even if it came from the chart. Keep the reflection exception if needed.
        let isCreatingFromReflection =
            !self.isEditMode &&
            self.reflectionCoordinator != nil &&
            self.diaryNote?.diaryNoteable?.type.lowercased() == "task" &&
            (self.diaryNote?.body?.isEmpty ?? true)

        let shouldShowEmojiButton =
            noteExists &&
            hasEmojis &&
            (self.pageState.value == .read) &&
            !isCreatingFromReflection  // preserve this rule

        if shouldShowEmojiButton {
            let spacer = UIView()
            spacer.autoSetDimensions(to: CGSize(width: 24, height: 24))
            self.titleRow.addArrangedSubview(spacer)
            self.titleRow.addArrangedSubview(self.titleLabel)
            self.titleRow.addArrangedSubview(self.emojiButton)
        } else {
            self.titleRow.addArrangedSubview(self.titleLabel)
        }

        // Hide/show back button
        self.closeButton.isHidden = hideBackInHeader
    }


    private func emojiItems(for category: EmojiTagCategory) -> [EmojiItem] {
        return self.cache.feedbackList[category.rawValue] ?? []
    }
    
    private func categoryForEmoji(diaryNote: DiaryNoteItem?) -> EmojiTagCategory {
        var category: EmojiTagCategory
        if let diaryType = DiaryNoteableType(rawValue: diaryNote?.diaryNoteable?.type.lowercased() ?? "none") {
            switch diaryType {
            case .none, .chart:
                category = .iHaveNoticed
            case .task:
                category = .reflections
            }
        } else {
            category = .none
        }
        
        return category
    }
    
    private func updateNextButton(pageState: PageState) {
        switch pageState {
        case .edit:
            footerView.setButtonText(StringsProvider.string(forKey: .diaryNoteCreateTextSave))
            footerView.setButtonEnabled(enabled: !self.textView.text.isEmpty)

        case .read:
            if isChartLinkedNote || wasJustCreatedHere {
                // After creation → show Close
                footerView.setButtonText(StringsProvider.string(forKey: .diaryNoteNoticedEmojiCloseButton))
                footerView.setButtonEnabled(enabled: true)
            } else {
                footerView.setButtonText(StringsProvider.string(forKey: .diaryNoteCreateTextSave))
                footerView.setButtonEnabled(enabled: true)
            }
        }
    }


    private func updateTextFields(pageState: PageState) {
        let textView = self.textView
        let editButton = self.editButton
        self.placeholderLabel.isHidden = !textView.text.isEmpty
        switch pageState {
        case .edit:
            textView.isEditable = true
            textView.isUserInteractionEnabled = true
            textView.textColor = self.standardColor
            editButton.isHidden = true
        case .read:
            textView.isEditable = false
            textView.isUserInteractionEnabled = false
            textView.textColor = self.inactiveColor
            editButton.isHidden = false
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
