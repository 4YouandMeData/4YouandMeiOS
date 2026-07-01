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
    
    enum PageState { case read, edit }
    
    private let pageState: BehaviorRelay<PageState> = BehaviorRelay<PageState>(value: .read)
    private let navigator: AppNavigator
    private let repository: Repository
    private let analytics: AnalyticsService
    private let reflectionCoordinator: ReflectionSectionCoordinator?
    private var selectedEmoji: EmojiItem?
    private var originalBody: String?
    // FUAM-3495 — The last value persisted to the backend (DB). Updated ONLY on load
    // and on successful save; never while typing. Source of truth for the cancel/revert
    // and for the footer button's saved-vs-dirty comparison.
    private var persistedBody: String?
    private var wasJustCreatedHere: Bool = false

    private lazy var backButton: UIButton = {
        let button = UIButton()
        button.setImage(ImagePalette.templateImage(withName: .backButtonNavigation), for: .normal)
        button.tintColor = ColorPalette.color(withType: .primaryText)
        button.autoSetDimension(.width, toSize: 32)
        button.imageView?.contentMode = .scaleAspectFit
        button.addTarget(self, action: #selector(self.closeButtonPressed), for: .touchUpInside)
        return button
    }()

    private lazy var titleRow: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        stack.distribution = .equalSpacing
        return stack
    }()
    
    private var isLinked: Bool {
        return diaryNote?.diaryNoteable != nil
    }

    private var isFirstSaveInThisVC: Bool {
        return !isEditMode && !wasJustCreatedHere
    }

    private var mustSendInsteadOfUpdate: Bool {
        return diaryNote == nil || isFirstSaveInThisVC
    }
    
    private var isReflectionLinkedNote: Bool {
        guard reflectionCoordinator != nil else { return false }
        return diaryNote?.diaryNoteable?.type.lowercased() == "task"
    }
    
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

        // Back button
        let backButtonContainerView = UIView()
        backButtonContainerView.addSubview(self.backButton)
        self.backButton.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .trailing)
        stackView.addArrangedSubview(backButtonContainerView)

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
        textView.isEditable = false               // Disable editing
        textView.showsVerticalScrollIndicator = true
        textView.typingAttributes = [.foregroundColor: ColorPalette.color(withType: .primaryText),
                                     .font: FontPalette.fontStyleData(forStyle: .header3).font,
                                     .paragraphStyle: style]
        textView.delegate = self
        textView.layer.borderWidth = 1
        textView.tintColor = ColorPalette.color(withType: .primary)
        textView.layer.borderColor = ColorPalette.color(withType: .inactive).cgColor
        textView.layer.cornerRadius = 8
        textView.clipsToBounds = true
        
        return textView
    }()
    
    private lazy var doneButton: UIBarButtonItem = {
        let button = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(self.doneButtonPressed))
        return button
    }()
    
    private lazy var editingToolbar: UIToolbar = {
        let toolBar = UIToolbar()
        toolBar.barStyle = .default
        toolBar.isTranslucent = true
        toolBar.tintColor = ColorPalette.color(withType: .primary)
        toolBar.sizeToFit()

        let cancelButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(self.cancelEdit))
        let spaceButton = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        toolBar.setItems([cancelButton, spaceButton, doneButton], animated: false)
        return toolBar
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
        buttonView.addTarget(target: self, action: #selector(self.footerButtonPressed))
        buttonView.setButtonText(StringsProvider.string(forKey: .diaryNoteNoticedEmojiCloseButton))
        buttonView.setButtonEnabled(enabled: true)
        
        return buttonView
    }()
    
    private var cache: CacheService
    private var diaryNote: DiaryNoteItem?
    private let maxCharacters: Int = 5000
    private var isEditMode: Bool
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
        self.persistedBody = dataPoint?.body
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
                self.updateTextFields(pageState: newState)
                self.updateTitleRow()
                self.updateFooterButton()
                self.view.endEditing(true)

                let shouldShowEditButton = (self.diaryNote != nil && newState == .read)
                self.editButton.isHidden = !shouldShowEditButton
            })
            .disposed(by: self.disposeBag)
        
        self.selectedEmoji = self.diaryNote?.feedbackTags?.last
        self.refreshEmojiButtonGlyph()
        
        self.loadNote()
        self.updateTitleRow()
        self.updateFooterButton()
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
        // FUAM-3495 — "Continue" erases changes, so revert to the PERSISTED body (the DB
        // value) rather than `originalBody`, which is re-snapshotted on every focus.
        // Rendered red (.destructive) because it is the discard action.
        let cancelAction = UIAlertAction(title: StringsProvider.string(forKey: .diaryNoteCancelConfirm),
                                         style: .destructive,
                                         handler: { [weak self] _ in
            guard let self = self else { return }
            // FUAM-3495 — Revert the textarea to the persisted (DB) value FIRST — purely
            // local, no server call — and dismiss the keyboard in the same run loop so
            // the restoration is concurrent with the keyboard closing (no lag).
            let dbBody = self.persistedBody ?? ""
            self.textView.text = dbBody
            self.placeholderLabel.isHidden = !dbBody.isEmpty
            self.limitLabel.text = "\(dbBody.count) / \(self.maxCharacters)"
            self.textView.resignFirstResponder()

            if self.diaryNote != nil {
                self.pageState.accept(.read)
            } else {
                self.pageState.accept(.edit)
            }
        })
        // "No" keeps editing, rendered in the study/tint color (.default).
        let confirmAction = UIAlertAction(title: StringsProvider.string(forKey: .diaryNoteCancelCancel),
                                          style: .default,
                                          handler: nil)
        self.showAlert(withTitle: StringsProvider.string(forKey: .diaryNoteCancelTitle),
                       message: StringsProvider.string(forKey: .diaryNoteCancelBody),
                       actions: [cancelAction, confirmAction],
                       tintColor: ColorPalette.color(withType: .primary))
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
    
    // FUAM-3495 — Single footer button with three states driven by dirty tracking:
    // SAVE (disabled) when there is nothing to save, SAVE (enabled) when there is
    // unsaved text, and CLOSE once the on-screen text matches the persisted body.
    @objc private func footerButtonPressed() {
        let mode = Self.footerButtonMode(currentText: self.textView.text,
                                         savedBody: self.persistedBody,
                                         noteExists: self.diaryNote != nil)
        switch mode {
        case .saveEnabled:
            self.doneButtonPressed()
        case .close:
            self.closeButtonPressed()
        case .saveDisabled:
            break
        }
    }

    @objc private func closeButtonPressed() {
        if let coordinator = self.reflectionCoordinator {
            coordinator.showSuccessPage()
            return
        }
        self.dismiss(animated: true) {
            self.navigator.switchToDiaryTab(presenter: self)
        }
    }
    
    @objc private func editButtonPressed() {
        self.originalBody = self.textView.text
        self.pageState.accept(.edit)
        self.textView.becomeFirstResponder()
    }
    
    @objc private func doneButtonPressed() {
        textView.resignFirstResponder()
        
        // Validate that text is not empty or only whitespace
        let trimmedText = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            // FUAM-3495 (req 2) — Defensive empty-save: show the default error popup
            // and navigate back once it is dismissed.
            self.showAlert(forError: nil, onDismiss: { [weak self] in self?.closeButtonPressed() })
            return
        }
        
        var noteToSave: DiaryNoteItem
        if var existing = diaryNote {
            existing.body = textView.text
            noteToSave = existing
        } else {
            noteToSave = DiaryNoteItem(
                diaryNoteId: nil,
                body: textView.text,
                interval: nil,
                diaryNoteable: nil
            )
        }

        if mustSendInsteadOfUpdate {
           
            // FUAM-3495 — Create the note (POST) then chain the best-effort emoji
            // attach (PATCH, one retry) behind the scenes. The note is always
            // persisted; on emoji failure the note stays saved and a default error
            // popup is shown.
            repository.sendDiaryNoteTextWithFeedback(
                diaryNote: noteToSave,
                emoji: self.selectedEmoji,
                fromChart: isLinked
            )
            .addProgress()
            .subscribe(onSuccess: { [weak self] (saved, feedbackSaved) in
                guard let self = self else { return }
                self.diaryNote = saved
                self.wasJustCreatedHere = true
                self.isEditMode = true
                self.originalBody = saved.body
                // FUAM-3495 — record the persisted body (fall back to the text we sent,
                // in case the create response does not echo the body).
                self.persistedBody = saved.body ?? noteToSave.body
                if self.isLinked && self.isReflectionLinkedNote {
                    self.reflectionCoordinator?.onReflectionCreated(
                        presenter: self,
                        reflectionType: .text,
                        diaryNote: saved
                    )
                }
                self.pageState.accept(.read)
                if !feedbackSaved {
                    // Note is saved; only the emoji attach failed.
                    self.showAlert(forError: nil)
                } else if let picked = self.selectedEmoji, picked.label != "none" {
                    // FUAM-3495 — the emoji was created by the chained PATCH, but the
                    // POST response does not include it. Refetch so feedbackTags carry
                    // the new server record id and a later emoji change swaps (not
                    // duplicates) it.
                    self.reloadDiaryNoteFromServer()
                }
            }, onFailure: { [weak self] error in
                guard let self = self else { return }
                self.navigator.handleError(error: error, presenter: self)
            })
            .disposed(by: disposeBag)

        } else {
            repository.updateDiaryNoteText(diaryNote: noteToSave)
                .addProgress()
                .subscribe(onSuccess: { [weak self] in
                    self?.diaryNote = noteToSave
                    self?.pageState.accept(.read)
                    self?.originalBody = self?.textView.text
                    // FUAM-3495 — the just-saved text is now the persisted body.
                    self?.persistedBody = noteToSave.body
                }, onFailure: { [weak self] error in
                    guard let self = self else { return }
                    self.navigator.handleError(error: error, presenter: self)
                })
                .disposed(by: disposeBag)
        }
    }

    @objc private func emojiButtonTapped() {
        
        let category = self.categoryForEmoji(diaryNote: self.diaryNote)
        let emojiItems = self.emojiItems(for: category)
        let emojiVC = EmojiPopupViewController(emojis: emojiItems,
                                               selected: self.selectedEmoji) { [weak self] selectedEmoji in
            guard let self = self, let emoji = selectedEmoji else { return }

            self.selectedEmoji = emoji
            self.refreshEmojiButtonGlyph()

            // FUAM-3495 — For a brand-new note (not yet persisted) just hold the pick
            // locally; the PATCH is chained after the POST on Save. For an existing
            // note persist immediately, then refetch so feedbackTags carry the real
            // server record ids for the next change.
            guard var diaryNote = self.diaryNote else { return }
            // The just-picked emoji is a new tag (catalog id == ""); the serializer
            // marks the prior server record(s) for destruction. Ensure the array
            // exists so the append is not silently dropped when feedbackTags is nil.
            if diaryNote.feedbackTags == nil { diaryNote.feedbackTags = [] }
            diaryNote.feedbackTags?.append(emoji)

            self.repository.updateDiaryNoteText(diaryNote: diaryNote)
                .addProgress()
                .subscribe(onSuccess: { [weak self] in
                    self?.reloadDiaryNoteFromServer()
                },
                           onFailure: { [weak self] error in
                    guard let self = self else { return }
                    self.navigator.handleError(error: error, presenter: self)
                }).disposed(by: self.disposeBag)
        }
        
        emojiVC.modalPresentationStyle = .overCurrentContext
        emojiVC.modalTransitionStyle = .crossDissolve
        self.present(emojiVC, animated: true)
    }

    // FUAM-3495 — Refetch the note so the local feedbackTags reflect the true server
    // state (real record ids). Without this, a second emoji change re-sends an
    // already-destroyed or empty-id tag for destruction and the backend errors, and
    // a text edit would re-send stale feedback_tags. Called after every successful
    // emoji persistence.
    private func reloadDiaryNoteFromServer() {
        guard let noteID = self.diaryNote?.id else { return }
        self.repository.getDiaryNoteText(noteID: noteID)
            .subscribe(onSuccess: { [weak self] fetched in
                guard let self = self else { return }
                self.diaryNote = fetched
                self.persistedBody = fetched.body
                self.selectedEmoji = fetched.feedbackTags?.last
                self.refreshEmojiButtonGlyph()
                self.updateFooterButton()
            }, onFailure: { [weak self] error in
                guard let self = self else { return }
                self.navigator.handleError(error: error, presenter: self)
            })
            .disposed(by: self.disposeBag)
    }

    // FUAM-3495 — Render the current selectedEmoji on the emoji button (or restore the
    // default icon when there is no real emoji).
    private func refreshEmojiButtonGlyph() {
        if let emoji = self.selectedEmoji, emoji.label != "none" {
            self.emojiButton.setImage(nil, for: .normal)
            self.emojiButton.setTitle(emoji.tag, for: .normal)
            self.emojiButton.titleLabel?.font = UIFont.systemFont(ofSize: 22)
        } else {
            self.emojiButton.setTitle(nil, for: .normal)
            self.emojiButton.setImage(ImagePalette.image(withName: .emojiICon), for: .normal)
        }
    }

    // MARK: - Private Methods

    // FUAM-3495 — The three footer states. Kept internal so a Quick spec can exercise
    // the rule without instantiating the view controller.
    enum FooterButtonMode: Equatable { case saveDisabled, saveEnabled, close }

    // FUAM-3495 — Pure rule for the footer button behavior. `savedBody` is the persisted
    // body (`diaryNote?.body`); when the on-screen text matches it (and a note exists)
    // there is nothing to save, so the button becomes CLOSE. Otherwise SAVE, enabled
    // only when the text is non-empty after trimming.
    static func footerButtonMode(currentText: String, savedBody: String?, noteExists: Bool) -> FooterButtonMode {
        let isSaved = noteExists && currentText == (savedBody ?? "")
        if isSaved { return .close }
        let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? .saveDisabled : .saveEnabled
    }

    private func updateFooterButton() {
        let mode = Self.footerButtonMode(currentText: self.textView.text,
                                         savedBody: self.persistedBody,
                                         noteExists: self.diaryNote != nil)
        switch mode {
        case .saveDisabled:
            self.footerView.setButtonText(StringsProvider.string(forKey: .diaryNoteCreateNoticedSave))
            self.footerView.setButtonEnabled(enabled: false)
        case .saveEnabled:
            self.footerView.setButtonText(StringsProvider.string(forKey: .diaryNoteCreateNoticedSave))
            self.footerView.setButtonEnabled(enabled: true)
        case .close:
            self.footerView.setButtonText(StringsProvider.string(forKey: .diaryNoteNoticedEmojiCloseButton))
            self.footerView.setButtonEnabled(enabled: true)
        }
    }

    private func updateTitleRow() {
        // Clear previous subviews
        self.titleRow.arrangedSubviews.forEach {
            self.titleRow.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        let category   = self.categoryForEmoji(diaryNote: self.diaryNote)
        let hasEmojis  = !self.emojiItems(for: category).isEmpty
        let noteExists = (self.diaryNote != nil)

        // Show emoji when the note exists and we're in READ state,
        //  even if it came from the chart. Keep the reflection exception if needed.
        let isCreatingFromReflection =
            !self.isEditMode &&
            self.reflectionCoordinator != nil &&
            self.diaryNote?.diaryNoteable?.type.lowercased() == "task" &&
            (self.diaryNote?.body?.isEmpty ?? true)
        
        // FUAM-3495 — Also show the emoji picker BEFORE saving a brand-new note,
        // so the user can pick the emoji while still editing the text.
        let shouldShowEmojiButton =
            hasEmojis &&
            !isCreatingFromReflection &&
            (
                (self.pageState.value == .read && noteExists) ||     // existing note (unchanged)
                (self.pageState.value == .edit && !noteExists)       // new note, pre-save picker
            )

        if shouldShowEmojiButton {
            let spacer = UIView()
            spacer.autoSetDimensions(to: CGSize(width: 24, height: 24))
            self.titleRow.addArrangedSubview(spacer)
            self.titleRow.addArrangedSubview(self.titleLabel)
            self.titleRow.addArrangedSubview(self.emojiButton)
        } else {
            self.titleRow.addArrangedSubview(self.titleLabel)
        }
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

    private func updateTextFields(pageState: PageState) {
        let textView = self.textView
        let editButton = self.editButton
        self.placeholderLabel.isHidden = !textView.text.isEmpty

        switch pageState {
        case .edit:
            textView.isEditable = true
            textView.isSelectable = true
            textView.inputAccessoryView = editingToolbar
            textView.textColor = self.standardColor
            editButton.isHidden = true
            
            // Update save button state when entering edit mode
            let trimmedText = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
            self.doneButton.isEnabled = !trimmedText.isEmpty

        case .read:
            textView.isEditable = false
            textView.isSelectable = false
            textView.inputAccessoryView = nil
            textView.textColor = self.inactiveColor
            editButton.isHidden = false
        }

        // If it was already first responder, refresh input views
        if textView.isFirstResponder {
            textView.reloadInputViews()
        }

        // FUAM-3495 — Keep the footer label in sync with the current state/text.
        self.updateFooterButton()
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
                    self.persistedBody = diaryNoteText.body
                    self.textView.text = diaryNoteText.body
                    self.limitLabel.text = "\(self.textView.text.count) / \(self.maxCharacters)"
                    self.updateTextFields(pageState: self.pageState.value)
                    self.updateFooterButton()
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
    
    func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
        return pageState.value == .edit
    }
    
    func textViewDidChangeSelection(_ textView: UITextView) {
        
    }
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        self.originalBody = textView.text
        self.placeholderLabel.isHidden = !textView.text.isEmpty
        
        // Update save button state when editing begins
        let trimmedText = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        self.doneButton.isEnabled = !trimmedText.isEmpty
        self.updateFooterButton()
    }
    
    func textViewDidChange(_ textView: UITextView) {
        self.placeholderLabel.isHidden = !textView.text.isEmpty
        self.limitLabel.text = "\(textView.text.count) / \(self.maxCharacters)"
        
        // Enable/disable save button based on whether text is empty or only whitespace
        let trimmedText = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        self.doneButton.isEnabled = !trimmedText.isEmpty
        self.updateFooterButton()

        if textView.text.count <= self.maxCharacters {
            textView.layer.borderColor = ColorPalette.color(withType: .inactive).cgColor
            self.limitLabel.textColor = ColorPalette.color(withType: .inactive)
            // FUAM-3495 — do NOT mutate diaryNote.body while typing; the persisted body
            // is tracked separately so cancel/revert and the footer dirty-check stay correct.
        } else {
            textView.layer.borderColor = UIColor.red.cgColor
            self.limitLabel.textColor = .red
        }
    }
}
