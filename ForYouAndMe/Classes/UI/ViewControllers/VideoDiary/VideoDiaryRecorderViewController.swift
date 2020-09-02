//
//  VideoDiaryRecorderViewController.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 27/08/2020.
//

import UIKit
import RxSwift

enum VideoDiaryState {
    case record(isRecording: Bool)
    case review(isPlaying: Bool)
    case submitted(submitDate: Date, isPlaying: Bool)
}

public class VideoDiaryRecorderViewController: UIViewController {
    
    private static let RecordTrackingTimeInterval: TimeInterval = 0.1
    
    private let taskIdentifier: String
    private let coordinator: VideoDiarySectionCoordinator
    private let repository: Repository
    private let navigator: AppNavigator
    
    private lazy var cameraView: EHCameraView = {
        let view = EHCameraView()
        view.delegate = self
        view.mergedFileExtension = self.videoOutputExtension
        view.configureTheCameraAttributes()
        return view
    }()
    
    private lazy var playerView: EHPlayerView = {
        let view = EHPlayerView()
        view.delegate = self
        return view
    }()
    
    private var mergedFileSize: UInt64 = 0
    private var recordDurationTime: TimeInterval = 0.0
    private var noOfPauses: Int = 0
    private let videoExtension = "mov"
    private var videoOutputExtension = "mp4"
    private var recordTrackingTimer: Timer?
    private var videoMergeQueued: Bool = false
    
    private let disposeBag = DisposeBag()
    
    let stackView: UIStackView = {
        let stackView = UIStackView.create(withAxis: .vertical)
        return stackView
    }()
    
    private lazy var videoDiaryPlayerView: VideoDiaryPlayerView = {
        let view = VideoDiaryPlayerView(delegate: self)
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
    
    private lazy var switchCameraButton: UIButton = {
        let button = UIButton()
        button.autoSetDimension(.width, toSize: 44.0)
        button.setImage(ImagePalette.image(withName: .cameraSwitch), for: .normal)
        button.addTarget(self, action: #selector(self.switchCameraButtonPressed), for: .touchUpInside)
        return button
    }()
    
    private var toolbar: UIView {
        let view = UIView()

        view.addSubview(self.lightButton)
        self.lightButton.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 0, left: 16.0, bottom: 0, right: 0.0),
                                                      excludingEdge: .trailing)
        
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
    }
    
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
        
        self.view.addSubview(self.stackView)
        self.stackView.autoPinEdgesToSuperviewSafeArea(with: .zero, excludingEdge: .bottom)
        self.stackView.autoPinEdge(toSuperviewEdge: .bottom)
        
        let playerButtonReferenceView = UIView()
        
        self.stackView.addBlankSpace(space: 16.0)
        self.stackView.addArrangedSubview(self.toolbar)
        self.stackView.addArrangedSubview(playerButtonReferenceView)
        self.stackView.addArrangedSubview(self.videoDiaryPlayerView)
        
        // Cannot simply add playerButton as subview of playerButtonReferenceView, because isUserInteractionEnabled would be inherited.
        // PlayerButtonReferenceView.isUserInteractionEnabled will be set to switched based on the playerView state
        // to allow tap on playerView
        self.view.addSubview(self.playerButton)
        self.playerButton.autoAlignAxis(.vertical, toSameAxisOf: playerButtonReferenceView)
        self.playerButton.autoAlignAxis(.horizontal, toSameAxisOf: playerButtonReferenceView)
        
        self.updateUI()
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.primary(hidden: true).style)
    }
    
    // MARK: - Private Methods
    
    private func updateUI() {
        self.videoDiaryPlayerView.updateState(newState: self.currentState, recordDurationTime: self.recordDurationTime)
        switch self.currentState {
        case .record(let isRecording):
            self.stackView.isUserInteractionEnabled = !isRecording
            self.cameraView.isHidden = false
            self.playerView.isHidden = true
            self.updateToolbar(currentTime: Int(self.recordDurationTime), isRunning: isRecording, isRecordState: true)
            self.updatePlayerButton(isRunning: isRecording, isRecordState: true)
        case .review(let isPlaying):
            self.stackView.isUserInteractionEnabled = !isPlaying // Needed to allow tap on playerView
            self.cameraView.isHidden = true
            self.playerView.isHidden = false
            self.updateToolbar(currentTime: Int(self.recordDurationTime), isRunning: isPlaying, isRecordState: false)
            self.updatePlayerButton(isRunning: isPlaying, isRecordState: false)
        case .submitted(_, let isPlaying):
            self.stackView.isUserInteractionEnabled = !isPlaying // Needed to allow tap on playerView
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
        self.navigator.pushProgressHUD()
        guard let videoData = try? Data.init(contentsOf: Constants.Task.videoResultURL) else {
            assertionFailure("Couldn't transform result data to expected network representation")
            self.navigator.handleError(error: nil, presenter: self, onDismiss: { [weak self] in
                self?.coordinator.onCancelTask()
            })
            return
        }
        let videoDataStream: String = videoData.base64EncodedString(options: NSData.Base64EncodingOptions.init(rawValue: 0))
        let taskNetworkResult = TaskNetworkResult(data: [:], attachedFile: videoDataStream)
        self.repository.sendTaskResult(taskId: self.taskIdentifier, taskResult: taskNetworkResult)
            .subscribe(onSuccess: { [weak self] in
                guard let self = self else { return }
                self.navigator.popProgressHUD()
                try? FileManager.default.removeItem(atPath: Constants.Task.videoResultURL.path)
                self.currentState = .submitted(submitDate: Date(), isPlaying: false)
                }, onError: { [weak self] error in
                    guard let self = self else { return }
                    self.navigator.popProgressHUD()
                    self.navigator.handleError(error: error,
                                               presenter: self,
                                               onDismiss: { [weak self] in
                                                self?.coordinator.onCancelTask()
                        },
                                               onRetry: { [weak self] in
                                                self?.sendResult()
                        }, dismissStyle: .destructive)
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
            self.cameraView.startRecording()
        } catch {
            self.navigator.handleError(error: error, presenter: self)
        }
    }
    
    private func stopRecording() {
        self.navigator.pushProgressHUD()
        self.recordTrackingTimer?.invalidate()
        self.currentState = .record(isRecording: false)
        self.cameraView.stopRecording()
        self.noOfPauses += 1
    }
    
    private func setOutputFileURL() throws -> URL {
        let outputFileName = "Video\(self.noOfPauses)"
        var isDir: ObjCBool = false
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: Constants.Task.videoResultURL.path, isDirectory: &isDir) {
            do {
                try fileManager.createDirectory(atPath: Constants.Task.videoResultURL.path,
                                                withIntermediateDirectories: false,
                                                attributes: nil)
            } catch let error {
                print(error)
            }
        }
        let fileURL = Constants.Task.videoResultURL.appendingPathComponent(outputFileName).appendingPathExtension(self.videoExtension)
        return fileURL
    }
    
    // TODO: Test purpose. Remove
    private func fakeSendResult() {
        self.navigator.pushProgressHUD()
        let closure: (() -> Void) = {
            self.navigator.popProgressHUD()
            self.currentState = .submitted(submitDate: Date(), isPlaying: false)
        }
        let delayTime = DispatchTime.now() + 2.0
        let dispatchWorkItem = DispatchWorkItem(block: closure)
        DispatchQueue.main.asyncAfter(deadline: delayTime, execute: dispatchWorkItem)
    }
    
    private func handleCompleteRecording() {
        // Adding Progress HUD here so that the user interaction is disabled until the video is saved to documents directory
        self.navigator.pushProgressHUD()
        self.cameraView.mergeRecordedVideos()
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
        if self.recordDurationTime >= Constants.Misc.VideoDiaryMaxDurationSeconds {
            self.videoMergeQueued = true
            self.stopRecording()
            return
        }
        self.currentState = .record(isRecording: true)
    }
}

extension VideoDiaryRecorderViewController: VideoDiaryPlayerViewDelegate {
    func mainButtonPressed() {
        switch self.currentState {
        case .record:
            self.handleCompleteRecording()
        case .review:
//            self.sendResult()
            self.fakeSendResult()
        case .submitted:
            self.coordinator.onRecordCompleted()
        }
    }
    
    func discardButtonPressed() {
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
    }
}

extension VideoDiaryRecorderViewController: EHCameraViewDelegate {
    func hasCaptureSessionErrorOccurred(error: CaptureSessionError) {
        // Alert will not be displayed because the view has not appeared yet. That's why using Async with delay.
        Async.mainQueueWithDelay(1, closure: { [weak self] in
            guard let self = self else { return }
            
            self.navigator.handleError(error: error, presenter: self)
            // TODO: Handle .cameraNotAuthorized, .micNotAuthorized
//            self.showInfoAlert(error.localizedDescription) { _ in
//                switch error {
//                case .cameraNotAuthorized, .micNotAuthorized:
//                    if let settings = URL(string: UIApplication.openSettingsURLString) {
//                        UIApplication.shared.open(settings)
//                    }
//                default:
//                    break
//                }
//            }
        })
    }
    
    func hasCaptureOutputErrorOccurred(error: CaptureOutputError) {
        self.navigator.handleError(error: error, presenter: self)
//        showInfoAlert(error.localizedDescription)
    }
    
    /// Method to disable iCloud sync for the video file recorded or show alert if some error occurred
    ///
    /// - Parameters:
    ///     - fileURL: URL of the video file recorded
    ///     - error: Error occured while recording the video
    func hasFinishedRecording(fileURL: URL?, error: Error?) {
        self.navigator.popProgressHUD()
        
        guard error == nil else {
            self.navigator.handleError(error: error, presenter: self)
            return
        }
        
        guard nil != fileURL else {
            self.navigator.handleError(error: nil, presenter: self)
            return
        }
        if self.videoMergeQueued {
            self.videoMergeQueued = false
            self.handleCompleteRecording()
        }
    }
    
    /// Method to assign the URL of the merged video to the player view and move to the submitRecording state
    ///
    /// - Parameter mergedVideoURL: URL of the merged video
    func didFinishMergingVideo(mergedVideoURL: URL?) {
        guard let mergedVideoURL = mergedVideoURL else { return }
        
        self.playerView.videoURL = mergedVideoURL
        
//        var mergedVideoFileURL = mergedVideoURL
//        mergedVideoFileURL.disableiCloudSync()
        self.mergedFileSize = mergedVideoURL.sizeInBytes
        self.navigator.popProgressHUD()
        
        self.currentState = .review(isPlaying: false)
        
//        dismissPopUpView { [weak self] _ in
//            guard let self = self else { return }
//
//            self.st
//
//            self.setIdentityTransformForRecordButton()
//            self.reviewRecordingView.removeFromSuperview()
//            self.configureSubmitRecordingView()
//            self.popupContainerViewHeight = self.submitRecordingViewCalculatedHeight
//            self.configurePopUpContainerView(subview: self.submitRecordingView)
//            self.view.layoutIfNeeded()
//            // Delay is given to load the new pop up view
//            Async.mainQueueWithDelay(0.5) { [weak self] in
//                guard let self = self else { return }
//
//                self.currentState = .submitRecording
//                self.handleCurrentState()
//            }
//        }
    }
    
    func hasVideoMergingErrorOccurred(error: VideoMergingError) {
        Async.mainQueue { [weak self] in
            guard let self = self else { return }
            self.navigator.popProgressHUD()
            self.navigator.handleError(error: error, presenter: self)
        }
    }
}

extension VideoDiaryRecorderViewController: EHPlayerViewDelegate {
    func hasFinishedPlaying() {
        switch self.currentState {
        case .record:
            assertionFailure("Unexpected record state")
        case .review:
            self.currentState = .review(isPlaying: false)
        case .submitted(let submitDate, _):
            self.currentState = .submitted(submitDate: submitDate, isPlaying: false)
        }
    }
    
    func tapGestureDidStart() {
//        self.playerButton.isHidden = false
    }
    
    func tapGestureWillEnd() {
//        self.playerButton.isHidden = (currentState == .playing ? true : false)
    }
    
    func sliderValueDidChange() {
//        self.playerButton.isHidden = true
    }
}
