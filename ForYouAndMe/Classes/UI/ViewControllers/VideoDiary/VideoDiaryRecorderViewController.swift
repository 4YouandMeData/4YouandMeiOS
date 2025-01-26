//
//  VideoDiaryRecorderViewController.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 27/08/2020.
//

import UIKit
import RxSwift
import AVFoundation

enum VideoDiaryState {
    case record(isRecording: Bool)
    case review(isPlaying: Bool)
    case submitted(submitDate: Date, isPlaying: Bool)
    case view(isPlaying: Bool)
}

public class VideoDiaryRecorderViewController: UIViewController {
    
    private static let HidePlayerButtonDelay: TimeInterval = 2.0
    private static let RecordTrackingTimeInterval: TimeInterval = 0.1
    
    private let taskIdentifier: String
    private let coordinator: VideoDiarySectionCoordinator
    private let repository: Repository
    private let navigator: AppNavigator
    private let analytics: AnalyticsService
    
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
    
    private var recordDurationTime: TimeInterval = 0.0
    private var lastSuccessfulRecordDurationTime: TimeInterval = 0.0
    private var noOfPauses: Int = 0
    private let videoExtension = "mov" // Extension of each video part
    private let mergedVideoExtension: FileDataExtension = .mp4
    private var recordTrackingTimer: Timer?
    private var hidePlayButtonTimer: Timer?
    private var recordMaxTimeExceeded: Bool { self.recordDurationTime >= Constants.Misc.VideoDiaryMaxDurationSeconds }
    
    private let disposeBag = DisposeBag()
    
    let stackView: UIStackView = {
        let stackView = UIStackView.create(withAxis: .vertical)
        return stackView
    }()
    
    private lazy var videoDiaryPlayerView: VideoDiaryPlayerView = {
        let view = VideoDiaryPlayerView(delegate: self,
                                        totalTime: Constants.Misc.VideoDiaryMaxDurationSeconds)
        return view
    }()
    
    private lazy var playerButton: UIButton = {
        let button = UIButton()
        button.autoSetDimensions(to: CGSize(width: 96.0, height: 96.0))
        button.addTarget(self, action: #selector(self.playerButtonPressed), for: .touchUpInside)
        return button
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
    
    private var currentState: VideoDiaryState = .record(isRecording: false) {
        didSet {
            self.updateUI()
        }
    }
    
    private let timeLabelAttributedTextStyle = AttributedTextStyle(fontStyle: .header2, colorType: .secondaryText)
    
    init(taskIdentifier: String, coordinator: VideoDiarySectionCoordinator) {
        self.taskIdentifier = taskIdentifier
        self.coordinator = coordinator
        self.repository = Services.shared.repository
        self.navigator = Services.shared.navigator
        self.analytics = Services.shared.analytics
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = UIColor.black
        
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
        
        self.updateUI()
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UIApplication.shared.isIdleTimerDisabled = true
        self.navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.primary(hidden: true).style)
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        UIApplication.shared.isIdleTimerDisabled = false
    }
    
    // MARK: - Private Methods
    
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
            self.stackView.isUserInteractionEnabled = !isPlaying // Needed to allow tap on playerView
            self.overlayView.isHidden = isPlaying
            self.playerButton.isHidden = isPlaying
            self.cameraView.isHidden = true
            self.playerView.isHidden = false
            self.updateToolbar(currentTime: Int(self.recordDurationTime), isRunning: isPlaying, isRecordState: false)
            self.updatePlayerButton(isRunning: isPlaying, isRecordState: false)
        }
    }
    
    private func updateToolbar(currentTime: Int, isRunning: Bool, isRecordState: Bool) {
        self.updateTimeLabel(currentTime: currentTime, isRunning: isRunning, isRecordState: isRecordState)
        if isRecordState {
            self.updateLightButton()
            // Switch camera during recording throw error 11818 from AVFoundation callback
            self.switchCameraButton.isHidden = isRunning
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
    
    private func sendResult() {
        AppNavigator.pushProgressHUD()
        guard let videoUrl = self.playerView.videoURL, let videoData = try? Data.init(contentsOf: videoUrl) else {
            assertionFailure("Couldn't transform result data to expected network representation")
            self.navigator.handleError(error: nil, presenter: self, onDismiss: { [weak self] in
                self?.coordinator.onCancelTask()
            })
            return
        }
        let videoResultFile = TaskNetworkResultFile(data: videoData, fileExtension: self.mergedVideoExtension)
        let taskNetworkResult = TaskNetworkResult(data: [:], attachedFile: videoResultFile)
        self.repository.sendTaskResult(taskId: self.taskIdentifier, taskResult: taskNetworkResult)
            .do(onDispose: { AppNavigator.popProgressHUD() })
            .subscribe(onSuccess: { [weak self] in
                guard let self = self else { return }
                try? FileManager.default.removeItem(atPath: Constants.Task.VideoResultURL.path)
                self.currentState = .submitted(submitDate: Date(), isPlaying: false)
            }, onError: { [weak self] error in
                guard let self = self else { return }
                self.navigator.handleError(error: error,
                                           presenter: self)
            }).disposed(by: self.disposeBag)
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
        self.analytics.track(event: .videoDiaryAction(AnalyticsParameter.recordingPaused.rawValue))
        AppNavigator.pushProgressHUD()
        self.cameraView.mergeRecordedVideos()
    }
    
    private func showPermissionAlert(withTitle title: String, message: String) {
        let actions: [UIAlertAction] = [
            UIAlertAction(title: StringsProvider.string(forKey: .videoDiaryMissingPermissionSettings),
                          style: .default,
                          handler: { [weak self] _ in self?.navigator.openSettings() }),
            UIAlertAction(title: StringsProvider.string(forKey: .videoDiaryMissingPermissionDiscard),
                          style: .destructive,
                          handler: { [weak self] _ in self?.coordinator.onCancelTask() })
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
                self.playerView.pauseVideo()
            }
        }
    }
}

extension VideoDiaryRecorderViewController: VideoDiaryPlayerViewDelegate {
    func mainButtonPressed() {
        switch self.currentState {
        case .record:
            self.handleCompleteRecording()
        case .review:
            self.sendResult()
        case .submitted:
            self.coordinator.onRecordCompleted()
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
                              handler: { [weak self] _ in self?.coordinator.onCancelTask() })
            ]
            self.showAlert(withTitle: StringsProvider.string(forKey: .videoDiaryDiscardTitle),
                           message: StringsProvider.string(forKey: .videoDiaryDiscardBody),
                           actions: actions,
                           tintColor: ColorPalette.color(withType: .primary))
        } else {
            self.coordinator.onCancelTask()
        }
    }
}

extension VideoDiaryRecorderViewController: CameraViewDelegate {
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

extension VideoDiaryRecorderViewController: PlayerViewDelegate {
    func hasFinishedPlaying() {
        switch self.currentState {
        case .record:
            assertionFailure("Unexpected record state")
        case .review:
            self.currentState = .review(isPlaying: false)
        case .submitted(let submitDate, _):
            self.currentState = .submitted(submitDate: submitDate, isPlaying: false)
        case .view:
            self.currentState = .review(isPlaying: false)
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

extension FileDataExtension {
    var avFileType: AVFileType {
        switch self {
        case .mp4: return .mp4
        case .m4a: return .m4a
        }
    }
}
