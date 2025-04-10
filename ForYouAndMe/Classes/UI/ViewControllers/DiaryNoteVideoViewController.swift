//
//  DiaryNoteVideoViewController.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 23/01/25.
//

import UIKit
import RxSwift
import TPKeyboardAvoiding
import RxRelay

class DiaryNoteVideoViewController: UIViewController {
    
    private static let HidePlayerButtonDelay: TimeInterval = 2.0
    private static let RecordTrackingTimeInterval: TimeInterval = 0.1
    private let timeLabelAttributedTextStyle = AttributedTextStyle(fontStyle: .header2, colorType: .secondaryText)
    private var diaryNoteItem: DiaryNoteItem?
    private let maxCharacters: Int = 500
    
    private let navigator: AppNavigator
    private let repository: Repository
    private let analytics: AnalyticsService
    private var storage: CacheService
    
    private let disposeBag = DisposeBag()
    
    private var recordDurationTime: TimeInterval = 0.0
    private var lastSuccessfulRecordDurationTime: TimeInterval = 0.0
    private var noOfPauses: Int = 0
    private let mergedVideoExtension: FileDataExtension = .mp4
    private var recordMaxTimeExceeded: Bool { self.recordDurationTime >= Constants.Misc.VideoDiaryNoteMaxDurationSeconds }
    private let videoExtension = "mov"
    private var recordTrackingTimer: Timer?
    private var hidePlayButtonTimer: Timer?
    private var isEditMode: Bool
    private var pollingDisposable: Disposable?
    private let pollingInterval: TimeInterval = 5.0 // Polling interval in seconds
    private var isPollingActive: Bool = false
    private var reflectionCoordinator: ReflectionSectionCoordinator?
    
    private var currentState: VideoDiaryState = .record(isRecording: false) {
        didSet {
            self.updateUI()
        }
    }
    
    private lazy var scrollView: TPKeyboardAvoidingScrollView = {
        let scrollView = TPKeyboardAvoidingScrollView()
        scrollView.keyboardDismissMode = .interactive
        return scrollView
    }()
    
    private lazy var footerView: GenericButtonView = {
        let buttonView = GenericButtonView(withTextStyleCategory: .transparentBackground(shadow: false ))
        return buttonView
    }()
    
    private lazy var cameraView: CameraView = {
        let view = CameraView()
        view.mergedFileType = self.mergedVideoExtension.avFileType
        view.delegate = self
        return view
    }()
    
    private lazy var playerView: PlayerView = {
        let view = PlayerView()
        view.delegate = self
        return view
    }()
    
    private lazy var timeLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        return label
    }()
    
    private lazy var lightButton: UIButton = {
        let button = UIButton()
        button.autoSetDimension(.width, toSize: 44.0)
        button.setImage(ImagePalette.image(withName: .flashOff), for: .normal)
        button.addTarget(self, action: #selector(self.lightButtonPressed), for: .touchUpInside)
        return button
    }()
    
    private lazy var filterButton: UIButton = {
        let button = UIButton()
        button.autoSetDimension(.height, toSize: 30.0)
        button.autoSetDimension(.width, toSize: 30.0)
        button.contentMode = .scaleAspectFit
        button.setImage(ImagePalette.image(withName: .filterOff), for: .normal)
        button.addTarget(self, action: #selector(self.filterCameraPressed), for: .touchUpInside)
        return button
    }()
    
    private lazy var switchCameraButton: UIButton = {
        let button = UIButton()
        button.autoSetDimension(.width, toSize: 44.0)
        button.setImage(ImagePalette.image(withName: .cameraSwitch), for: .normal)
        button.addTarget(self, action: #selector(self.switchCameraButtonPressed), for: .touchUpInside)
        return button
    }()
    
    private lazy var toolbar: UIView = {
        let view = UIView()
        
        // Flash button
        view.addSubview(self.lightButton)
        self.lightButton.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 0, left: 16.0, bottom: 0, right: 0.0),
                                                      excludingEdge: .trailing)
        
        // Filter button
        view.addSubview(self.filterButton)
        self.filterButton.autoPinEdge(toSuperviewEdge: .top)
        self.filterButton.autoPinEdge(.leading, to: .trailing, of: self.lightButton, withOffset: 0.0, relation: .greaterThanOrEqual)
        
        // Switch camera
        view.addSubview(self.switchCameraButton)
        self.switchCameraButton.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 0, left: 0.0, bottom: 0, right: 16.0),
                                                             excludingEdge: .leading)
        
        view.addSubview(self.timeLabel)
        self.timeLabel.autoPinEdge(toSuperviewEdge: .top)
        self.timeLabel.autoPinEdge(toSuperviewEdge: .bottom)
        self.timeLabel.autoAlignAxis(toSuperviewAxis: .vertical)
        self.timeLabel.autoPinEdge(.leading, to: .trailing, of: self.lightButton, withOffset: 16.0, relation: .greaterThanOrEqual)
        self.switchCameraButton.autoPinEdge(.trailing, to: .leading, of: self.timeLabel, withOffset: 16.0, relation: .greaterThanOrEqual)
        
        return view
    }()
    
    private let overlayView: UIView = {
        let view = UIView()
        view.backgroundColor = ColorPalette.overlayColor
        return view
    }()
    
    let stackView: UIStackView = {
        let stackView = UIStackView.create(withAxis: .vertical)
        return stackView
    }()
    
    private lazy var videoDiaryPlayerView: VideoDiaryPlayerView = {
        let view = VideoDiaryPlayerView(delegate: self,
                                        totalTime: Constants.Misc.VideoDiaryNoteMaxDurationSeconds)
        return view
    }()
    
    private lazy var playerButton: UIButton = {
        let button = UIButton()
        button.autoSetDimensions(to: CGSize(width: 96.0, height: 96.0))
        button.addTarget(self, action: #selector(self.playerButtonPressed), for: .touchUpInside)
        return button
    }()
    
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

        stackView.addLabel(withText: StringsProvider.string(forKey: .diaryNoteCreateVideoTitle),
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
    
    init(diaryNoteItem: DiaryNoteItem?,
         isEdit: Bool,
         reflectionCoordinator: ReflectionSectionCoordinator?) {
        self.navigator = Services.shared.navigator
        self.repository = Services.shared.repository
        self.storage = Services.shared.storageServices
        self.analytics = Services.shared.analytics
        self.isEditMode = isEdit
        self.diaryNoteItem = diaryNoteItem
        self.reflectionCoordinator = reflectionCoordinator
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
        self.view.backgroundColor = UIColor.black
        
        if isEditMode {
            self.setupUIVideoWatch()
        } else {
            self.setupUIVideoRecord()
        }
        self.updateUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.primary(hidden: true).style)
    }
    
    // MARK: - Actions
    
    @objc private func playerButtonPressed() {
        switch self.currentState {
        case .record(let isRecording):
            if isRecording {
                self.stopRecording()
            } else {
                self.startRecording()
            }
        case .review(let isPlaying):
            if isPlaying {
                self.playerView.pauseVideo()
            } else {
                self.playerView.playVideo()
            }
            self.currentState = .review(isPlaying: !isPlaying)
        case .submitted(let submitDate, let isPlaying):
            if isPlaying {
                self.playerView.pauseVideo()
            } else {
                self.playerView.playVideo()
            }
            self.currentState = .submitted(submitDate: submitDate, isPlaying: !isPlaying)
        case .view(let isPlaying):
            if isPlaying {
                self.playerView.pauseVideo()
            } else {
                self.playerView.playVideo()
            }
            self.currentState = .view(isPlaying: !isPlaying)
        }
        self.updateFilterButton()
    }
    
    @objc private func filterCameraPressed() {
        do {
            try self.cameraView.toggleFilters()
            self.updateFilterButton()
        } catch {
            debugPrint(error)
        }
    }
    
    @objc private func lightButtonPressed() {
        do {
            try self.cameraView.toggleFlash()
            self.updateLightButton()
        } catch {
            debugPrint(error)
        }
    }
    
    @objc private func switchCameraButtonPressed() {
        do {
            try self.cameraView.switchCamera()
            self.updateLightButton()
        } catch {
            debugPrint(error)
        }
    }
    
    @objc private func fireTimer() {
        self.recordDurationTime += Self.RecordTrackingTimeInterval
        if self.recordMaxTimeExceeded {
            self.stopRecording()
            return
        }
        self.currentState = .record(isRecording: true)
    }
    
    @objc private func hidePlayButton() {
        self.playerButton.isHidden = true
        self.hidePlayButtonTimer = nil
    }
    
    @objc func applicationDidBecomeActive() {
        switch currentState {
        case .record: break
        case .review(let isPlaying):
            if isPlaying {
                self.playerView.playVideo()
            }
        case .submitted(_, let isPlaying):
            if isPlaying {
                self.playerView.playVideo()
            }
        case .view(let isPlaying):
            if isPlaying {
                self.playerView.playVideo()
            }
        }
    }
    
    @objc private func applicationWillResign() {
        switch currentState {
        case .record(let isRecording):
            if isRecording {
                self.stopRecording()
            }
        case .review(let isPlaying):
            if isPlaying {
                self.playerView.pauseVideo()
            }
        case .submitted(_, let isPlaying):
            if isPlaying {
                self.playerView.pauseVideo()
            }
        case .view(let isPlaying):
            if isPlaying {
                self.playerView.playVideo()
            }
        }
    }
    
    @objc private func doneButtonPressed() {
        self.textView.resignFirstResponder()
        self.footerView.isHidden = false
        self.footerView.setButtonEnabled(enabled: true)
    }
    
    @objc private func closeButtonPressed() {
        self.genericCloseButtonPressed(completion: {
            self.navigator.switchToDiaryTab(presenter: self)
        })
    }
    
    @objc private func editButtonPressed() {
        self.footerView.isHidden = false
        self.textView.isEditable = true
        self.textView.becomeFirstResponder()
    }
    
    @objc private func updateButtonPressed() {
        if var diaryNote = self.diaryNoteItem {
            diaryNote.body = self.textView.text
            self.repository.updateDiaryNoteText(diaryNote: diaryNote)
                .addProgress()
                .subscribe(onSuccess: { [weak self] in
                    guard let self = self else { return }
                    self.textView.isEditable = false
                    self.textView.isSelectable = false
                    self.footerView.isHidden = true
                }, onFailure: { [weak self] error in
                    guard let self = self else { return }
                    self.navigator.handleError(error: error, presenter: self)
                }).disposed(by: self.disposeBag)
        }
    }
    
    // MARK: - Private Methods
    
    private func setupUIVideoWatch() {
        
        self.view.subviews.forEach { $0.removeFromSuperview() }
        
        self.view.backgroundColor = ColorPalette.color(withType: .secondary)
        self.view.addSubview(self.headerView)
        self.view.addSubview(self.scrollView)
        self.view.addSubview(self.footerView)
        
        self.scrollView.addSubview(self.playerView)
                    
        self.headerView.autoPinEdges(toSuperviewMarginsExcludingEdge: .bottom)
        self.footerView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets.zero, excludingEdge: .top)
        self.footerView.setButtonText(StringsProvider.string(forKey: .diaryNoteCreateVideoSave))
        self.footerView.setButtonEnabled(enabled: false)
        self.footerView.isHidden = true
        self.footerView.addTarget(target: self, action: #selector(self.updateButtonPressed))
        
        self.scrollView.autoPinEdge(.top, to: .bottom, of: self.headerView)
        self.scrollView.autoPinEdge(.leading, to: .leading, of: self.view)
        self.scrollView.autoPinEdge(.trailing, to: .trailing, of: self.view)
        self.scrollView.autoPinEdge(.bottom, to: .top, of: self.footerView)
        
        self.playerView.autoPinEdge(.leading, to: .leading, of: self.view)
        self.playerView.autoPinEdge(.trailing, to: .trailing, of: self.view)
        self.playerView.autoPinEdge(.top, to: .top, of: self.scrollView)
        self.playerView.autoSetDimension(.height, toSize: 320)
        
        let containerTextView = UIView()
        containerTextView.addSubview(self.textView)
        
        let transcribeStatus = diaryNoteItem?.transcribeStatus
        if transcribeStatus == .pending || transcribeStatus == .error {
            self.setupUITrascribe(withContainer: containerTextView)
        } else if transcribeStatus == .success {
            self.textView.isEditable = false
            self.textView.isSelectable = false
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
        }
        
        self.scrollView.addSubview(containerTextView)

        containerTextView.autoPinEdge(.top, to: .bottom, of: self.playerView, withOffset: 30)
        containerTextView.autoPinEdge(.leading, to: .leading, of: self.view)
        containerTextView.autoPinEdge(.trailing, to: .trailing, of: self.view)
        containerTextView.autoPinEdge(.bottom, to: .top, of: self.footerView)
        
        self.playerView.addSubview(self.playerButton)
        self.playerButton.autoAlignAxis(.vertical, toSameAxisOf: self.playerView)
        self.playerButton.autoAlignAxis(.horizontal, toSameAxisOf: self.playerView)
        
        guard let videoURL = diaryNoteItem?.urlString else { return }
        self.playerView.videoURL = URL(string: videoURL)
        
        self.currentState = .view(isPlaying: false)
    }
    
    private func setupUITrascribe(withContainer containerStackView: UIView) {
        
        let transcribeStatus = diaryNoteItem?.transcribeStatus == .pending ?
        LoadingTranscribeAudioStyleCategory.loading :
        LoadingTranscribeAudioStyleCategory.error
        
        if diaryNoteItem?.transcribeStatus == .pending {
            self.startPolling()
        }
        let loadingView = LoadingTranscribeAudio(initWithStyle: transcribeStatus)
        containerStackView.addSubview(loadingView)
        loadingView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 8.0,
                                                                    left: 26.0,
                                                                    bottom: 8.0,
                                                                    right: 26.0), excludingEdge: .bottom)
    }
    
    private func setupUIVideoRecord() {
        
        self.view.subviews.forEach { $0.removeFromSuperview() }
        
        self.view.addSubview(self.cameraView)
        self.cameraView.autoPinEdgesToSuperviewEdges()
        
        self.view.addSubview(self.playerView)
        self.playerView.autoPinEdgesToSuperviewEdges()
        
        // Overlay
        self.view.addSubview(self.overlayView)
        self.overlayView.autoPinEdgesToSuperviewEdges()
        
        self.view.addSubview(self.stackView)
        self.stackView.autoPinEdgesToSuperviewSafeArea(with: .zero, excludingEdge: .bottom)
        self.stackView.autoPinEdge(toSuperviewEdge: .bottom)
        
        let toolbarReferenceView = UIView()
        let playerButtonReferenceView = UIView()
        
        self.stackView.addBlankSpace(space: 16.0)
        self.stackView.addArrangedSubview(toolbarReferenceView)
        self.stackView.addArrangedSubview(playerButtonReferenceView)
        self.stackView.addArrangedSubview(self.videoDiaryPlayerView)
        
        // Cannot simply add playerButton as subview of the stackView, because isUserInteractionEnabled would be inherited.
        // PlayerButtonReferenceView.isUserInteractionEnabled will be set to switched based on the playerView state
        // to allow tap on playerView
        self.view.addSubview(self.playerButton)
        self.playerButton.autoAlignAxis(.vertical, toSameAxisOf: playerButtonReferenceView)
        self.playerButton.autoAlignAxis(.horizontal, toSameAxisOf: playerButtonReferenceView)
        
        // Cannot simply add the toolbar as subview of the stackView, because isUserInteractionEnabled would be inherited
        // and would prevent tap on playerView
        self.view.addSubview(self.toolbar)
        self.toolbar.autoPinEdge(.leading, to: .leading, of: toolbarReferenceView)
        self.toolbar.autoPinEdge(.trailing, to: .trailing, of: toolbarReferenceView)
        self.toolbar.autoPinEdge(.top, to: .top, of: toolbarReferenceView)
        self.toolbar.autoPinEdge(.bottom, to: .bottom, of: toolbarReferenceView)
        
        self.addApplicationWillResignObserver()
        self.addApplicationDidBecomeActiveObserver()
    }
    
    private func updateUI() {
        self.invalidatedHidePlayerButtonTimer()
        self.videoDiaryPlayerView.updateState(newState: self.currentState, recordDurationTime: self.recordDurationTime)
        switch self.currentState {
        case .record(let isRecording):
            self.stackView.isUserInteractionEnabled = !isRecording
            self.playerButton.isHidden = false
            self.overlayView.isHidden = isRecording
            self.cameraView.isHidden = false
            self.playerView.isHidden = true
            self.updateToolbar(currentTime: Int(self.recordDurationTime), isRunning: isRecording, isRecordState: true)
            self.updatePlayerButton(isRunning: isRecording, isRecordState: true)
        case .review(let isPlaying):
            self.stackView.isUserInteractionEnabled = !isPlaying // Needed to allow tap on playerView
            self.overlayView.isHidden = isPlaying
            self.playerButton.isHidden = isPlaying
            self.cameraView.isHidden = true
            self.playerView.isHidden = false
            self.updateToolbar(currentTime: Int(self.recordDurationTime), isRunning: isPlaying, isRecordState: false)
            self.updatePlayerButton(isRunning: isPlaying, isRecordState: false)
        case .submitted(_, let isPlaying):
            self.stackView.isUserInteractionEnabled = !isPlaying // Needed to allow tap on playerView
            self.overlayView.isHidden = isPlaying
            self.playerButton.isHidden = isPlaying
            self.cameraView.isHidden = true
            self.playerView.isHidden = false
            self.updateToolbar(currentTime: Int(self.recordDurationTime), isRunning: isPlaying, isRecordState: false)
            self.updatePlayerButton(isRunning: isPlaying, isRecordState: false)
        case .view(let isPlaying):
            self.overlayView.isHidden = isPlaying
            self.playerButton.isHidden = isPlaying
            self.playerView.isHidden = false
            self.updatePlayerButton(isRunning: isPlaying, isRecordState: false)
        }
    }
    
    private func showPermissionAlert(withTitle title: String, message: String) {
        let actions: [UIAlertAction] = [
            UIAlertAction(title: StringsProvider.string(forKey: .videoDiaryMissingPermissionSettings),
                          style: .default,
                          handler: { [weak self] _ in self?.navigator.openSettings() }),
            UIAlertAction(title: StringsProvider.string(forKey: .videoDiaryMissingPermissionDiscard),
                          style: .destructive,
                          handler: { [weak self] _ in self?.dismiss(animated: true)/*self?.coordinator.onCancelTask()*/ })
        ]
        self.showAlert(withTitle: title, message: message, actions: actions, tintColor: ColorPalette.color(withType: .primary))
    }
    
    private func addApplicationWillResignObserver() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.applicationWillResign),
                                               name: UIApplication.willResignActiveNotification,
                                               object: nil)
    }
    
    internal func addApplicationDidBecomeActiveObserver() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.applicationDidBecomeActive),
                                               name: UIApplication.didBecomeActiveNotification,
                                               object: nil)
    }
    
    private func invalidatedHidePlayerButtonTimer() {
        self.hidePlayButtonTimer?.invalidate()
        self.hidePlayButtonTimer = nil
    }
    
    private func startRecording() {
        do {
            let outputFileURL = try self.setOutputFileURL()
            self.cameraView.recordedVideoExtension = self.videoExtension
            try self.cameraView.setOutputFileURL(fileURL: outputFileURL)
            self.recordTrackingTimer = Timer.scheduledTimer(timeInterval: Self.RecordTrackingTimeInterval,
                                                            target: self,
                                                            selector: #selector(self.fireTimer),
                                                            userInfo: nil,
                                                            repeats: true)
            self.currentState = .record(isRecording: true)
            self.analytics.track(event: .videoDiaryAction(self.noOfPauses > 0 ?
                                                          AnalyticsParameter.contact.rawValue :
                                                            AnalyticsParameter.recordingStarted.rawValue))
            
            self.cameraView.startRecording()
        } catch {
            self.navigator.handleError(error: nil, presenter: self)
        }
    }
    
    private func stopRecording() {
        // AppNavigator.pushProgressHUD()
        self.recordTrackingTimer?.invalidate()
        self.currentState = .record(isRecording: false)
        self.cameraView.stopRecording()
        self.noOfPauses += 1
    }
    
    private func updateToolbar(currentTime: Int, isRunning: Bool, isRecordState: Bool) {
        self.updateTimeLabel(currentTime: currentTime, isRunning: isRunning, isRecordState: isRecordState)
        if isRecordState {
            self.updateLightButton()
            // Switch camera during recording throw error 11818 from AVFoundation callback
            self.switchCameraButton.isHidden = isRunning
            self.lightButton.isHidden = false
        } else {
            self.lightButton.isHidden = true
            self.switchCameraButton.isHidden = true
        }
    }
    
    private func updateTimeLabel(currentTime: Int, isRunning: Bool, isRecordState: Bool) {
        if isRunning, isRecordState {
            self.timeLabel.setTime(currentTime: currentTime,
                                   totalTime: Int(Constants.Misc.VideoDiaryMaxDurationSeconds),
                                   attributedTextStyle: self.timeLabelAttributedTextStyle)
        } else {
            self.timeLabel.attributedText = NSAttributedString.create(withText: StringsProvider.string(forKey: .videoDiaryRecorderTitle),
                                                                      attributedTextStyle: self.timeLabelAttributedTextStyle)
        }
    }
    
    private func updateFilterButton() {
        
        switch self.currentState {
        case .record(let isRecording):
            self.filterButton.isHidden = isRecording
            return
        case .review(_): // hide filter button during review or recording
            self.filterButton.isHidden = true
            return
        case .view(_):
            self.filterButton.isHidden = true
        default:
            if self.cameraView.filterMode == .on {
                self.filterButton.setImage(ImagePalette.image(withName: .filterOn), for: .normal)
            } else {
                self.filterButton.setImage(ImagePalette.image(withName: .filterOff), for: .normal)
            }
        }
    }
    
    private func updateLightButton() {
        guard let currentCameraPosition = self.cameraView.currentCameraPosition, currentCameraPosition == .back else {
            self.lightButton.isHidden = true
            return
        }
        self.lightButton.isHidden = false
        if self.cameraView.flashMode == .on {
            self.lightButton.setImage(ImagePalette.image(withName: .flashOn), for: .normal)
        } else {
            self.lightButton.setImage(ImagePalette.image(withName: .flashOff), for: .normal)
        }
    }
    
    private func updatePlayerButton(isRunning: Bool, isRecordState: Bool) {
        if isRunning {
            self.playerButton.setImage(ImagePalette.image(withName: .videoPause), for: .normal)
        } else {
            if isRecordState {
                self.playerButton.setImage(ImagePalette.image(withName: .videoRecordResume), for: .normal)
            } else {
                self.playerButton.setImage(ImagePalette.image(withName: .videoPlay), for: .normal)
            }
        }
    }
    
    private func setOutputFileURL() throws -> URL {
        let outputFileName = "\(CameraView.videoFilenamePrefix)\(self.noOfPauses)"
        var isDir: ObjCBool = false
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: Constants.Task.VideoResultURL.path, isDirectory: &isDir) {
            try fileManager.createDirectory(atPath: Constants.Task.VideoResultURL.path,
                                            withIntermediateDirectories: false,
                                            attributes: nil)
        }
        let fileURL = Constants.Task.VideoResultURL.appendingPathComponent(outputFileName).appendingPathExtension(self.videoExtension)
        return fileURL
    }
    
    private func handleCompleteRecording() {
        // Adding Progress HUD here so that the user interaction is disabled until the video is saved to documents directory
        AppNavigator.pushProgressHUD()
        self.cameraView.mergeRecordedVideos()
    }
    
    private func sendResult() {
        AppNavigator.pushProgressHUD()
        guard let videoUrl = self.playerView.videoURL, let videoData = try? Data.init(contentsOf: videoUrl) else {
            assertionFailure("Couldn't transform result data to expected network representation")
            self.navigator.handleError(error: nil, presenter: self, onDismiss: { [weak self] in
                self?.dismiss(animated: true)
            })
            return
        }
        let videoResultFile = DiaryNoteFile(data: videoData, fileExtension: self.mergedVideoExtension)
        self.repository.sendDiaryNoteVideo(diaryNoteRef: self.diaryNoteItem ?? DiaryNoteItem(diaryNoteId: nil,
                                                                                             body: nil,
                                                                                             interval: nil,
                                                                                             diaryNoteable: nil),
                                           file: videoResultFile)
            .do(onDispose: { AppNavigator.popProgressHUD() })
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] diaryNote in
                guard let self = self else { return }
                self.diaryNoteItem = diaryNote
                guard let coordinator = self.reflectionCoordinator else {
                    self.onRecordCompleted()
                    DispatchQueue.main.async {
                        self.startPolling() // Start polling after successful creation
                        self.setupUIVideoWatch()
                    }
                    return
                }
                coordinator.onReflectionCreated(presenter: self, reflectionType: .audio)
            }, onFailure: { [weak self] error in
                guard let self = self else { return }
                self.navigator.handleError(error: error,
                                           presenter: self)
            }).disposed(by: self.disposeBag)
    }
    
    public func onRecordCompleted() {
        // TODO: gestire il caso in cui il video sia partito
        try? FileManager.default.removeItem(atPath: Constants.Task.VideoResultURL.path)
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
            self.setupUIVideoWatch()
        }
    }

    private func handlePollingError(_ error: Error) {
        print("Polling error: \(error.localizedDescription)")
        // Optional: Show an error message to the user or retry
    }
}

extension DiaryNoteVideoViewController: UITextViewDelegate {
    
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

extension DiaryNoteVideoViewController: CameraViewDelegate {
    func hasCaptureSessionErrorOccurred(error: CaptureSessionError) {
        // Alert will not be displayed because the view has not appeared yet. That's why using Async with delay.
        Async.mainQueueWithDelay(1, closure: { [weak self] in
            guard let self = self else { return }
            switch error {
            case .cameraNotAuthorized:
                self.showPermissionAlert(withTitle: StringsProvider.string(forKey: .videoDiaryMissingPermissionTitleCamera),
                                         message: StringsProvider.string(forKey: .videoDiaryMissingPermissionBodyCamera))
            case .micNotAuthorized:
                self.showPermissionAlert(withTitle: StringsProvider.string(forKey: .videoDiaryMissingPermissionTitleMic),
                                         message: StringsProvider.string(forKey: .videoDiaryMissingPermissionBodyMic))
            default:
                self.navigator.handleError(error: error, presenter: self)
            }
        })
    }
    
    func hasCaptureOutputErrorOccurred(error: CaptureOutputError) {
        self.recordDurationTime = self.lastSuccessfulRecordDurationTime
        self.recordTrackingTimer?.invalidate()
        self.currentState = .record(isRecording: false)
        self.navigator.handleError(error: error, presenter: self)
    }
    
    func hasFinishedRecording(fileURL: URL?, error: Error?) {
        AppNavigator.popProgressHUD()
        
        guard nil == error, nil != fileURL else {
            print("VideoDiaryRecorderViewController - Error while writing video on file: \(String(describing: error))")
            self.navigator.handleError(error: nil, presenter: self)
            self.recordDurationTime = self.lastSuccessfulRecordDurationTime
            self.currentState = .record(isRecording: false)
            return
        }
        
        self.lastSuccessfulRecordDurationTime = self.recordDurationTime
        if self.recordMaxTimeExceeded {
            self.handleCompleteRecording()
        }
    }
    
    func didFinishMergingVideo(mergedVideoURL: URL?) {
        guard let mergedVideoURL = mergedVideoURL else { return }
        
        self.playerView.videoURL = mergedVideoURL
        AppNavigator.popProgressHUD()
        
        self.currentState = .review(isPlaying: false)
    }
    
    func hasVideoMergingErrorOccurred(error: VideoMergingError) {
        Async.mainQueue { [weak self] in
            guard let self = self else { return }
            AppNavigator.popProgressHUD()
            self.navigator.handleError(error: error, presenter: self)
        }
    }
}

extension DiaryNoteVideoViewController: PlayerViewDelegate {
    func hasFinishedPlaying() {
        switch self.currentState {
        case .record:
            assertionFailure("Unexpected record state")
        case .review:
            self.currentState = .review(isPlaying: false)
        case .submitted(let submitDate, _):
            self.currentState = .submitted(submitDate: submitDate, isPlaying: false)
        case .view:
            self.currentState = .view(isPlaying: false)
        }
    }
    
    func tapGestureDidStart() {
        self.playerButton.isHidden = !self.playerButton.isHidden
        self.invalidatedHidePlayerButtonTimer()
        if !self.playerButton.isHidden {
            self.hidePlayButtonTimer = Timer.scheduledTimer(timeInterval: Self.HidePlayerButtonDelay,
                                                            target: self,
                                                            selector: #selector(self.hidePlayButton),
                                                            userInfo: nil,
                                                            repeats: false)
        }
    }
    
    func tapGestureWillEnd() {}
    
    func sliderValueDidChange() {}
}

extension DiaryNoteVideoViewController: VideoDiaryPlayerViewDelegate {
    func mainButtonPressed() {
        switch self.currentState {
        case .record:
            self.handleCompleteRecording()
        case .review:
            self.sendResult()
        case .submitted:
            self.onRecordCompleted()
        case .view:
            return
        }
    }
    
    func discardButtonPressed() {
        if self.recordDurationTime > 0.0 {
            let actions: [UIAlertAction] = [
                UIAlertAction(title: StringsProvider.string(forKey: .videoDiaryDiscardCancel),
                              style: .default,
                              handler: nil),
                UIAlertAction(title: StringsProvider.string(forKey: .videoDiaryDiscardConfirm),
                              style: .destructive,
                              handler: { [weak self] _ in self?.dismiss(animated: true)/*self?.coordinator.onCancelTask()*/ })
            ]
            self.showAlert(withTitle: StringsProvider.string(forKey: .videoDiaryDiscardTitle),
                           message: StringsProvider.string(forKey: .videoDiaryDiscardBody),
                           actions: actions,
                           tintColor: ColorPalette.color(withType: .primary))
        } else {
            self.dismiss(animated: true)
        }
    }
}
