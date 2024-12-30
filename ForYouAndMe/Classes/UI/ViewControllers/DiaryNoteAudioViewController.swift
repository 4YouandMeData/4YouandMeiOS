//
//  DiaryNoteAudioViewController.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 04/12/24.
//

import UIKit
import RxSwift
import TPKeyboardAvoiding
import RxRelay

class ActionButton: UIButton {
    var action: (() -> Void)?
}

class DiaryNoteAudioViewController: UIViewController {
    
    fileprivate enum PageState { case read, edit, transcribe }
    public fileprivate(set) var standardColor: UIColor = ColorPalette.color(withType: .primaryText)
    public fileprivate(set) var errorColor: UIColor = ColorPalette.color(withType: .primaryText)
    public fileprivate(set) var inactiveColor: UIColor = ColorPalette.color(withType: .inactive)
    
    private let navigator: AppNavigator
    private let repository: Repository
    private let analytics: AnalyticsService
    private let audioPlayerManager = AudioPlayerManager()
    private let audioAssetManager = AudioAssetManager()
    private var audioFileURL: URL?
    private let pageState: BehaviorRelay<PageState> = BehaviorRelay<PageState>(value: .read)
    
    private var pollingDisposable: Disposable?
    private let pollingInterval: TimeInterval = 5.0 // Polling interval in seconds
    private var isPollingActive: Bool = false
    
    private let disposeBag = DisposeBag()
    private let totalTimeLabelAttributedTextStyle = AttributedTextStyle(fontStyle: .title,
                                                                        colorType: .primaryText,
                                                                        textAlignment: .center)
    
    private let currentTimeLabelAttributedTextStyle = AttributedTextStyle(fontStyle: .title,
                                                                          colorType: .primaryText,
                                                                          textAlignment: .center)
    
    private let totalTime = Constants.Misc.AudioDiaryMaxDurationSeconds
    private var recordDurationTime: TimeInterval = 0.0
    
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

        stackView.addLabel(withText: "Audio Recording",
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
    
    private lazy var slider: UISlider = {
        let slider = UISlider()
        slider.minimumValue = 0
        slider.maximumValue = 100
        if let originalThumbImage = ImagePalette.image(withName: .circular) {
            let thumbWithShadow = originalThumbImage.withShadow(shadowColor: .black,
                                                                 shadowOffset: CGSize(width: 0, height: 2),
                                                                 shadowBlur: 4,
                                                                 shadowOpacity: 0.3)
            slider.setThumbImage(thumbWithShadow, for: .normal)
            slider.setThumbImage(thumbWithShadow, for: .highlighted)
        }
        slider.tintColor = ColorPalette.color(withType: .primary)
        slider.addTarget(self, action: #selector(self.onSliderValChanged(slider:event:)), for: .valueChanged)
        return slider
    }()
    
    private lazy var recordButton: ActionButton = {
        let recordButton = ActionButton()
        let recordButtonImage = ImagePalette.image(withName: .audioRecButton)
        recordButton.setImage(recordButtonImage, for: .normal)
        recordButton.imageView?.contentMode = .scaleAspectFit
        recordButton.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside)
        var config = recordButton.configuration ?? UIButton.Configuration.plain()
        config.contentInsets = NSDirectionalEdgeInsets(top: 4.0, leading: 4.0, bottom: 4.0, trailing: 4.0)
        recordButton.configuration = config
        recordButton.autoSetDimension(.height, toSize: 68)
        
        return recordButton
    }()
    
    private lazy var footerView: GenericButtonView = {

        let buttonView = GenericButtonView(withTextStyleCategory: .transparentBackground(shadow: false ))
        buttonView.addTarget(target: self, action: #selector(self.saveButtonPressed))
        return buttonView
    }()
    
    private lazy var timeLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        return label
    }()
    
    private lazy var scrollView: UIScrollView = {
        let scrollView = TPKeyboardAvoidingScrollView()
        scrollView.keyboardDismissMode = .interactive
        return scrollView
    }()
    
    private var storage: CacheService
    private var diaryNoteItem: DiaryNoteItem?
    private let maxCharacters: Int = 500
    private var isEditMode: Bool
    private let isFromChart: Bool
    
    init(withDiaryNote diaryNote: DiaryNoteItem?,
         isEditMode: Bool,
         isFromChart: Bool) {
        self.navigator = Services.shared.navigator
        self.repository = Services.shared.repository
        self.storage = Services.shared.storageServices
        self.analytics = Services.shared.analytics
        self.isEditMode = isEditMode
        self.isFromChart = isFromChart
        self.diaryNoteItem = diaryNote
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        print("DiaryNoteTextViewController - deinit")
        stopPolling()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = ColorPalette.color(withType: .secondary)
        
        // Header Stack View
        self.view.addSubview(self.headerView)
        self.headerView.autoPinEdges(toSuperviewMarginsExcludingEdge: .bottom)
        
        self.view.addSubview(self.scrollView)
                
        // Footer
        self.view.addSubview(self.footerView)
        footerView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets.zero, excludingEdge: .top)
        footerView.setButtonText("Save")
        self.footerView.setButtonEnabled(enabled: false)
        
        self.setupUI()
        
        self.scrollView.autoPinEdge(.top, to: .bottom, of: self.headerView)
        self.scrollView.autoPinEdge(.leading, to: .leading, of: self.view)
        self.scrollView.autoPinEdge(.trailing, to: .trailing, of: self.view)
        self.scrollView.autoPinEdge(.bottom, to: .top, of: self.footerView)
        
        self.audioPlayerManager.delegate = self
        try? audioPlayerManager.setupAudioSession()
        
        self.pageState
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] newPageState in
                print("PageState updated to: \(newPageState)")
                self?.updateNextButton(pageState: newPageState)
                self?.updateTextFields(pageState: newPageState)
                self?.view.endEditing(true)
        }).disposed(by: self.disposeBag)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.primary(hidden: true).style)
    }
    
    // MARK: - Actions
    
    @objc private func editButtonPressed() {
        self.pageState.accept(.edit)
        self.textView.becomeFirstResponder()
    }
    
    @objc private func closeButtonPressed() {
        self.genericCloseButtonPressed(completion: {
            self.navigator.switchToDiaryTab(presenter: self)
        })
    }
    
    @objc private func doneButtonPressed() {
        self.textView.resignFirstResponder()
    }
    
    @objc private func saveButtonPressed() {
        AppNavigator.pushProgressHUD()
        guard let audioUrl = self.audioFileURL,
              let audioData = try? Data.init(contentsOf: audioUrl) else {
            assertionFailure("Couldn't transform result data to expected network representation")
            return
        }
         
        let audioResultFile = DiaryNoteFile(data: audioData, fileExtension: .m4a)
        self.repository.sendDiaryNoteAudio(diaryNoteRef: diaryNoteItem ?? DiaryNoteItem(diaryNoteId: nil,
                                                                                        body: nil,
                                                                                        interval: nil,
                                                                                        diaryNoteable: nil),
                                           file: audioResultFile,
                                           fromChart: false)
            .do(onDispose: { AppNavigator.popProgressHUD() })
            .observeOn(MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] diaryNote in
                guard let self = self else { return }
                self.diaryNoteItem = diaryNote
                try? FileManager.default.removeItem(atPath: Constants.Note.NoteResultURL.path)
                DispatchQueue.main.async {
                    self.pageState.accept(.transcribe)
                    self.startPolling() // Start polling after successful creation
                }
            }, onError: { [weak self] error in
                guard let self = self else { return }
                self.navigator.handleError(error: error,
                                           presenter: self)
            }).disposed(by: self.disposeBag)
    }
    
    @objc private func updateButtonPressed() {
        if var diaryNote = self.diaryNoteItem {
            diaryNote.body = self.textView.text
            self.repository.updateDiaryNoteText(diaryNote: diaryNote)
                .addProgress()
                .subscribe(onSuccess: { [weak self] in
                    guard let self = self else { return }
                    self.closeButtonPressed()
                }, onError: { [weak self] error in
                    guard let self = self else { return }
                    self.navigator.handleError(error: error, presenter: self)
                }).disposed(by: self.disposeBag)
        }
    }
    
    @objc private func buttonTapped(_ sender: ActionButton) {
        sender.action?()
    }
    
    @objc private func onSliderValChanged(slider: UISlider, event: UIEvent) {
        let seekTime = TimeInterval(slider.value)
        audioPlayerManager.seek(to: seekTime)
    }
    
    // MARK: - Private Methods
    
    private func setupUI() {
        self.scrollView.subviews.forEach { $0.removeFromSuperview() }
        // StackView
        let containerStackView = UIStackView.create(withAxis: .vertical)
        self.scrollView.addSubview(containerStackView)
        containerStackView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 0.0,
                                                                  left: Constants.Style.DefaultHorizontalMargins,
                                                                  bottom: 0.0,
                                                                  right: Constants.Style.DefaultHorizontalMargins))
        containerStackView.autoAlignAxis(toSuperviewAxis: .vertical)
        
        if isEditMode {
            // Diary Note is present and I want listen recorded audio
            self.setupPlayerView(withContainer: containerStackView)
            let transcribeStatus = diaryNoteItem?.transcribeStatus
            if transcribeStatus == .pending || transcribeStatus == .error {
                self.setupUITrascribe(withContainer: containerStackView)
            } else if transcribeStatus == .success {
                self.setupUIListen(withContainer: containerStackView)
            }
        } else {
            // I want record a new audio
            self.setupUIRecord(withContainer: containerStackView)
        }
    }
    
    private func setupUIRecord(withContainer containerStackView: UIStackView) {
        
        containerStackView.addBlankSpace(space: 50.0)
        // Image
        containerStackView.addHeaderImage(image: ImagePalette.image(withName: .audioRecording), height: 80.0)
        containerStackView.addBlankSpace(space: 70)
        // Title
        let timeLabelContainerView = UIView()
        timeLabelContainerView.addSubview(self.timeLabel)
        self.timeLabel.autoPinEdgesToSuperviewEdges()
        self.timeLabel.autoAlignAxis(toSuperviewAxis: .vertical)
        self.timeLabel.autoAlignAxis(toSuperviewAxis: .horizontal)
        
        self.timeLabel.setTime(currentTime: Int(self.recordDurationTime),
                               totalTime: Int(totalTime),
                               attributedTextStyle: self.totalTimeLabelAttributedTextStyle,
                               currentTimeAttributedTextStyle: self.currentTimeLabelAttributedTextStyle)
        containerStackView.addArrangedSubview(timeLabelContainerView)
        containerStackView.addBlankSpace(space: 120)
        containerStackView.addArrangedSubview(self.recordButton)
        self.recordButton.action = { [weak self] in
            self?.audioPlayerManager.handleTap()
        }
    }
    
    private func setupPlayerView(withContainer containerStackView: UIStackView) {
        
        containerStackView.addBlankSpace(space: 24.0)
        let playButtonImage = ImagePalette.image(withName: .audioPlayButton)
        self.recordButton.setImage(playButtonImage, for: .normal)
        self.recordButton.imageView?.contentMode = .scaleAspectFit
        var config = self.recordButton.configuration ?? UIButton.Configuration.plain()
        config.contentInsets = NSDirectionalEdgeInsets(top: 4.0, leading: 4.0, bottom: 4.0, trailing: 4.0)
        self.recordButton.configuration = config
        self.recordButton.autoSetDimension(.height, toSize: 68)
        self.recordButton.action = { [weak self] in
            guard let diaryNoteItem = self?.diaryNoteItem, let urlString = diaryNoteItem.urlString else { return }
            self?.audioPlayerManager.playAudio(from: URL(string: urlString)!)
        }
        
        containerStackView.addArrangedSubview(self.recordButton)
        containerStackView.addBlankSpace(space: 24.0)
        
        // Time Label
        let timeLabelContainerView = UIView()
        timeLabelContainerView.addSubview(self.timeLabel)
        self.timeLabel.autoPinEdgesToSuperviewEdges()
        self.timeLabel.autoAlignAxis(toSuperviewAxis: .vertical)
        self.timeLabel.autoAlignAxis(toSuperviewAxis: .horizontal)
        
        if let urlString = diaryNoteItem?.urlString, let urlAudio = URL(string: urlString) {
            audioAssetManager.fetchAudioDuration(from: urlAudio) { duration in
                self.recordDurationTime = duration ?? 0
                self.timeLabel.setTime(currentTime: 0,
                                       totalTime: Int(self.recordDurationTime),
                                       attributedTextStyle: self.totalTimeLabelAttributedTextStyle,
                                       currentTimeAttributedTextStyle: self.currentTimeLabelAttributedTextStyle)
            }
        }
        
        containerStackView.addArrangedSubview(timeLabelContainerView)
        containerStackView.addBlankSpace(space: 60)
        containerStackView.addArrangedSubview(self.slider)
        self.slider.autoPinEdge(.leading, to: .leading, of: containerStackView)
        self.slider.autoPinEdge(.trailing, to: .trailing, of: containerStackView)
        
        containerStackView.addBlankSpace(space: 60)
    }
    
    private func setupUIListen(withContainer containerStackView: UIStackView) {
        
        let containerTextView = UIView()
        containerTextView.addSubview(self.textView)
        self.textView.text = self.diaryNoteItem?.body
        
        self.textView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 0,
                                                                      left: 12.0,
                                                                      bottom: 0,
                                                                      right: 12.0))
        // Limit label
        containerTextView.addSubview(self.limitLabel)
        self.limitLabel.textColor = .lightGray
        self.limitLabel.autoPinEdge(.top, to: .bottom, of: self.textView)
        self.limitLabel.autoPinEdge(.right, to: .right, of: self.textView)
        self.limitLabel.autoPinEdge(.left, to: .left, of: self.textView)
        self.limitLabel.text = "\(self.textView.text.count) / \(self.maxCharacters)"
        
        let editButton = UIButton()
        editButton.setImage(ImagePalette.image(withName: .editAudioNote), for: .normal)
        editButton.addTarget(self, action: #selector(self.editButtonPressed), for: .touchUpInside)
        containerTextView.addSubview(editButton)
        editButton.autoPinEdge(.bottom, to: .bottom, of: self.textView, withOffset: -8.0)
        editButton.autoPinEdge(.right, to: .right, of: self.textView, withOffset: -8.0)
        editButton.autoSetDimension(.width, toSize: 24.0)

        // Placeholder label
        self.textView.addSubview(self.placeholderLabel)
        self.placeholderLabel.isHidden = !textView.text.isEmpty
        self.placeholderLabel.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: CGFloat(self.textView.font!.pointSize/2),
                                                                              left: 5,
                                                                              bottom: 10,
                                                                              right: 10))
        containerStackView.addArrangedSubview(containerTextView)
        containerTextView.autoPinEdge(.top, to: .bottom, of: self.slider, withOffset: 30)
        containerTextView.autoPinEdge(.leading, to: .leading, of: self.view)
        containerTextView.autoPinEdge(.trailing, to: .trailing, of: self.view)
        containerTextView.autoPinEdge(.bottom, to: .top, of: self.footerView, withOffset: -30)
    }
    
    private func setupUITrascribe(withContainer containerStackView: UIStackView) {
        
        let transcribeStatus = diaryNoteItem?.transcribeStatus == .pending ?
        LoadingTranscribeAudioStyleCategory.loading :
        LoadingTranscribeAudioStyleCategory.error
        
        if diaryNoteItem?.transcribeStatus == .pending {
            self.startPolling()
        }
        let loadingView = LoadingTranscribeAudio(initWithStyle: transcribeStatus)
        let containerLoadingView = UIView()
        containerLoadingView.addSubview(loadingView)
        loadingView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 8.0,
                                                                    left: 26.0,
                                                                    bottom: 8.0,
                                                                    right: 26.0))
        containerStackView.addArrangedSubview(containerLoadingView)
        
        self.footerView.addTarget(target: self, action: #selector(self.updateButtonPressed))
    }
    
    private func updateNextButton(pageState: PageState) {
        let button = self.footerView
        switch pageState {
        case .edit:
            button.setButtonEnabled(enabled: true)
            button.addTarget(target: self, action: #selector(self.updateButtonPressed))
        case .read:
            button.setButtonEnabled(enabled: false)
        case .transcribe:
            self.isEditMode = true
            button.setButtonEnabled(enabled: false)
            self.setupUI()
        }
    }
    
    private func updateTextFields(pageState: PageState) {
        let textView = self.textView
        self.placeholderLabel.isHidden = !textView.text.isEmpty
        switch pageState {
        case .edit:
            textView.isHidden = false
            textView.isEditable = true
            textView.isUserInteractionEnabled = true
            textView.textColor = self.standardColor
        case .read:
            textView.isHidden = false
            textView.isEditable = false
            textView.isUserInteractionEnabled = false
            textView.textColor = self.inactiveColor
        case .transcribe:
            textView.isHidden = false
        }
    }
    
    // MARK: - Polling Methods

    private func startPolling() {
        guard let diaryNoteId = self.diaryNoteItem?.id, !isPollingActive else { return }

        isPollingActive = true
        pollingDisposable = Observable<Int>
            .interval(RxTimeInterval.seconds(Int(pollingInterval)), scheduler: MainScheduler.instance)
            .flatMapLatest { [weak self] _ -> Observable<DiaryNoteItem?> in
                guard let self = self else { return Observable.just(nil) }
                return self.repository.getDiaryNoteAudio(noteID: diaryNoteId).map { $0 as DiaryNoteItem? }
                    .asObservable()
            }
            .subscribe(onNext: { [weak self] diaryNoteItem in
                guard let self = self, let diaryNoteItem = diaryNoteItem else { return }
                self.handlePollingResponse(diaryNoteItem: diaryNoteItem)
            }, onError: { [weak self] error in
                self?.stopPolling()
                self?.handlePollingError(error)
            })
    }

    private func stopPolling() {
        pollingDisposable?.dispose()
        pollingDisposable = nil
        isPollingActive = false
    }

    private func handlePollingResponse(diaryNoteItem: DiaryNoteItem) {
        if diaryNoteItem.transcribeStatus == .success || diaryNoteItem.transcribeStatus == .error {
            self.diaryNoteItem = diaryNoteItem
            self.stopPolling()
            self.isEditMode = true
            self.pageState.accept(.read)
            self.setupUI()
        }
    }

    private func handlePollingError(_ error: Error) {
        print("Polling error: \(error.localizedDescription)")
        // Optional: Show an error message to the user or retry
    }
}

extension DiaryNoteAudioViewController: UITextViewDelegate {
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        self.placeholderLabel.isHidden = !textView.text.isEmpty
    }
    
    func textViewDidChange(_ textView: UITextView) {
        self.placeholderLabel.isHidden = !textView.text.isEmpty
        self.limitLabel.text = "\(textView.text.count) / \(self.maxCharacters)"
        if textView.text.count <= self.maxCharacters {
            textView.layer.borderColor = ColorPalette.color(withType: .inactive).cgColor
            self.limitLabel.textColor = ColorPalette.color(withType: .inactive)
        } else {
            textView.layer.borderColor = UIColor.red.cgColor
            self.limitLabel.textColor = .red
        }
    }
}

extension DiaryNoteAudioViewController: AudioPlayerManagerDelegate {
    func didPausePlaying() {
        let playButtonImage = ImagePalette.image(withName: .audioPlayButton)
        recordButton.setImage(playButtonImage, for: .normal)
        recordButton.action = { [weak self] in
            guard let self = self else { return }
            guard let diaryNoteItem = self.diaryNoteItem,
                    diaryNoteItem.urlString != nil else {
                self.audioPlayerManager.playRecordedAudio()
                return
            }
            self.audioPlayerManager.resumeAudio()
        }
        recordButton.imageView?.contentMode = .scaleAspectFit
    }
    
    func didResumePlaying() {
        let playButtonImage = ImagePalette.image(withName: .audioPauseButton)
        recordButton.setImage(playButtonImage, for: .normal)
        recordButton.action = { [weak self] in
            self?.audioPlayerManager.pauseAudio()
        }
        recordButton.imageView?.contentMode = .scaleAspectFit
    }
    
    func didUpdateRecordingTime(elapsedTime: TimeInterval) {
        self.timeLabel.setRecordTime(currentTime: Int(elapsedTime),
                                     attributedTextStyle: self.totalTimeLabelAttributedTextStyle,
                                     currentTimeAttributedTextStyle: self.currentTimeLabelAttributedTextStyle)
    }
    
    func didStartRecording() {
        self.timeLabel.setTime(currentTime: 0,
                               totalTime: Int(self.totalTime),
                               attributedTextStyle: self.totalTimeLabelAttributedTextStyle,
                               currentTimeAttributedTextStyle: self.currentTimeLabelAttributedTextStyle)
        let pauseButtonImage = ImagePalette.image(withName: .audioPauseButton)
        recordButton.setImage(pauseButtonImage, for: .normal)
        recordButton.action = { [weak self] in
            self?.audioPlayerManager.handleTap()
        }
    }
    
    func didFinishRecording(fileURL: URL?, duration: TimeInterval?, error: (any Error)?) {
        if let error {
            self.showAlert(withTitle: "Error",
                           message: error.localizedDescription,
                           dismissButtonText: "OK")
        }
        
        self.footerView.setButtonEnabled(enabled: true)
        self.recordDurationTime = duration ?? 0
        self.slider.maximumValue = Float(duration ?? 0)
        self.audioFileURL = fileURL
        self.timeLabel.setTime(currentTime: 0,
                               totalTime: Int(duration ?? 0),
                               attributedTextStyle: self.totalTimeLabelAttributedTextStyle,
                               currentTimeAttributedTextStyle: self.currentTimeLabelAttributedTextStyle)
        let playButtonImage = ImagePalette.image(withName: .audioPlayButton)
        recordButton.setImage(playButtonImage, for: .normal)
        recordButton.action = { [weak self] in
            self?.audioPlayerManager.playRecordedAudio()
        }
        recordButton.imageView?.contentMode = .scaleAspectFit
    }
    
    func didStartPlaying() {
        self.timeLabel.setTime(currentTime: 0,
                               totalTime: 0,
                               attributedTextStyle: self.totalTimeLabelAttributedTextStyle,
                               currentTimeAttributedTextStyle: self.currentTimeLabelAttributedTextStyle)
        let pauseButtonImage = ImagePalette.image(withName: .audioPauseButton)
        recordButton.setImage(pauseButtonImage, for: .normal)
        recordButton.imageView?.contentMode = .scaleAspectFit
        recordButton.action = { [weak self] in
            self?.audioPlayerManager.pauseAudio()
        }
    }
    
    func didFinishPlaying(success: Bool) {
        self.timeLabel.setTime(currentTime: 0,
                               totalTime: Int(self.recordDurationTime),
                               attributedTextStyle: self.totalTimeLabelAttributedTextStyle,
                               currentTimeAttributedTextStyle: self.currentTimeLabelAttributedTextStyle)
        self.slider.value = self.slider.maximumValue
        let playButtonImage = ImagePalette.image(withName: .audioPlayButton)
        recordButton.setImage(playButtonImage, for: .normal)
        recordButton.imageView?.contentMode = .scaleAspectFit
        recordButton.action = { [weak self] in
            guard let self = self else { return }
            guard let diaryNoteItem = self.diaryNoteItem, let urlString = diaryNoteItem.urlString else {
                self.audioPlayerManager.playRecordedAudio()
                return
            }
            self.slider.value = Float(0)
            self.audioPlayerManager.playAudio(from: URL(string: urlString)!)
        }
    }
    
    func didEncounterError(error: AudioPlayerError) {
        print("Error playing audio: \(error.localizedDescription)")
    }
    
    func didUpdatePlaybackTime(currentTime: TimeInterval, totalTime: TimeInterval, isPlaying: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // Aggiornamento della timeLabel e del UISlider
            self.timeLabel.setTime(currentTime: Int(currentTime),
                                   totalTime: Int(totalTime),
                                   attributedTextStyle: self.totalTimeLabelAttributedTextStyle,
                                   currentTimeAttributedTextStyle: self.currentTimeLabelAttributedTextStyle)
            if isPlaying {
                let pauseButtonImage = ImagePalette.image(withName: .audioPauseButton)
                self.recordButton.setImage(pauseButtonImage, for: .normal)
                self.recordButton.imageView?.contentMode = .scaleAspectFit
            }
            
            if totalTime > 0 {
                self.recordDurationTime = totalTime
                self.slider.maximumValue = Float(totalTime)
            }
            print("currentTime: \(currentTime), totalTime: \(totalTime)")
            self.slider.value = Float(currentTime)
        }
    }
}
