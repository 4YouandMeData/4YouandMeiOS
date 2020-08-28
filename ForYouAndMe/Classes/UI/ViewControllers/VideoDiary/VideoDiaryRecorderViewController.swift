//
//  VideoDiaryRecorderViewController.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 27/08/2020.
//

import UIKit
import RxSwift

enum VideoDiaryState {
    case record(currentTime: Int, isRecording: Bool)
    case review(currentTime: Int, isPlaying: Bool)
    case sumitted(currentTime: Int, submitDate: Date, isPlaying: Bool)
}

public class VideoDiaryRecorderViewController: UIViewController {
    
    private let taskIdentifier: String
    private let coordinator: VideoDiarySectionCoordinator
    private let repository: Repository
    private let navigator: AppNavigator
    
    private let disposeBag = DisposeBag()
    
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
    
    private var currentState: VideoDiaryState = .record(currentTime: 0, isRecording: false) {
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
        
        let stackView = UIStackView.create(withAxis: .vertical)
        self.view.addSubview(stackView)
        stackView.autoPinEdgesToSuperviewSafeArea(with: .zero, excludingEdge: .bottom)
        stackView.autoPinEdge(toSuperviewEdge: .bottom)
        
        let playerButtonContainerView = UIView()
        playerButtonContainerView.addSubview(self.playerButton)
        self.playerButton.autoCenterInSuperview()
        
        stackView.addBlankSpace(space: 16.0)
        stackView.addArrangedSubview(self.timeLabel)
        stackView.addArrangedSubview(playerButtonContainerView)
        stackView.addArrangedSubview(self.videoDiaryPlayerView)
        
        self.updateUI()
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.primary(hidden: true).style)
    }
    
    // MARK: - Private Methods
    
    private func updateUI() {
        self.videoDiaryPlayerView.updateState(newState: self.currentState)
        
        switch self.currentState {
        case .record(let currentTime, let isRecording):
            self.updateTimeLabel(currentTime: currentTime, isPlaying: isRecording)
            self.playerButton.setImage(ImagePalette.image(withName: .videoPause), for: .normal)
            if isRecording {
                self.playerButton.setImage(ImagePalette.image(withName: .videoPause), for: .normal)
            } else {
                self.playerButton.setImage(ImagePalette.image(withName: .videoRecordResume), for: .normal)
            }
        case .review(let currentTime, let isPlaying):
            self.updateTimeLabel(currentTime: currentTime, isPlaying: isPlaying)
            if isPlaying {
                self.playerButton.setImage(ImagePalette.image(withName: .videoPause), for: .normal)
            } else {
                self.playerButton.setImage(ImagePalette.image(withName: .videoPlay), for: .normal)
            }
        case .sumitted(let currentTime, _, let isPlaying):
            self.updateTimeLabel(currentTime: currentTime, isPlaying: isPlaying)
            if isPlaying {
                self.playerButton.setImage(ImagePalette.image(withName: .videoPause), for: .normal)
            } else {
                self.playerButton.setImage(ImagePalette.image(withName: .videoPlay), for: .normal)
            }
        }
    }
    
    private func updateTimeLabel(currentTime: Int, isPlaying: Bool) {
        if isPlaying {
            self.timeLabel.setTime(currentTime: currentTime,
                                   totalTime: Constants.Misc.VideoDiaryMaxDurationSeconds,
                                   attributedTextStyle: self.timeLabelAttributedTextStyle)
        } else {
            self.timeLabel.attributedText = NSAttributedString.create(withText: StringsProvider.string(forKey: .videoDiaryRecorderTitle),
                                                                      attributedTextStyle: self.timeLabelAttributedTextStyle)
        }
    }
    
    private func sendResult() {
        self.navigator.pushProgressHUD()
        guard let videoData = try? Data.init(contentsOf: Constants.Task.videoResultURL) else {
            assertionFailure("Couldn't transform result data to expected network representation")
            self.navigator.handleError(error: nil, presenter: self, onDismiss: { [weak self] in
                guard let self = self else { return }
                self.coordinator.onDiscardedRecord(presenter: self)
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
                self.currentState = .sumitted(currentTime: 0, submitDate: Date(), isPlaying: false)
                }, onError: { [weak self] error in
                    guard let self = self else { return }
                    self.navigator.popProgressHUD()
                    self.navigator.handleError(error: error,
                                               presenter: self,
                                               onDismiss: { [weak self] in
                                                guard let self = self else { return }
                                                self.coordinator.onDiscardedRecord(presenter: self)
                        },
                                               onRetry: { [weak self] in
                                                self?.sendResult()
                        }, dismissStyle: .destructive)
            }).disposed(by: self.disposeBag)
    }
    
    // TODO: Test purpose. Remove
    private func fakeSendResult() {
        self.navigator.pushProgressHUD()
        let closure: (() -> Void) = {
            self.navigator.popProgressHUD()
            self.currentState = .sumitted(currentTime: 0, submitDate: Date(), isPlaying: false)
        }
        let delayTime = DispatchTime.now() + 2.0
        let dispatchWorkItem = DispatchWorkItem(block: closure)
        DispatchQueue.main.asyncAfter(deadline: delayTime, execute: dispatchWorkItem)
    }
    
    // MARK: - Actions
    
    @objc private func playerButtonPressed() {
        // TODO: Replace with player current time
        let playerCurrentTime: Int = 32
        
        switch self.currentState {
        case .record(_, let isRecording):
            self.currentState = .record(currentTime: playerCurrentTime, isRecording: !isRecording)
        case .review(_, let isPlaying):
            self.currentState = .review(currentTime: playerCurrentTime, isPlaying: !isPlaying)
        case .sumitted(_, let submitDate, let isPlaying):
            self.currentState = .sumitted(currentTime: playerCurrentTime, submitDate: submitDate, isPlaying: !isPlaying)
        }
    }
}

extension VideoDiaryRecorderViewController: VideoDiaryPlayerViewDelegate {
    func mainButtonPressed() {
        switch self.currentState {
        case .record:
            self.currentState = .review(currentTime: 0, isPlaying: false)
        case .review:
//            self.sendResult()
            self.fakeSendResult()
        case .sumitted:
            self.coordinator.onRecordCompleted()
        }
    }
    
    func recordButtonPressed() {
        // TODO: Replace with player current time
        let playerCurrentTime: Int = 32
        
        self.currentState = .record(currentTime: playerCurrentTime, isRecording: true)
    }
    
    func discardButtonPressed() {
        self.coordinator.onDiscardedRecord(presenter: self)
    }
}
