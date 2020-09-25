//
//  IntroVideoViewController.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 18/09/2020.
//

import UIKit
import AVKit

class IntroVideoViewController: UIViewController {
    
    private let layerView: UIView = {
        let view = UIView()
        return view
    }()
    
    private let overlayView: UIView = {
        let view = UIView()
        view.backgroundColor = ColorPalette.overlayColor
        view.isUserInteractionEnabled = false
        return view
    }()
    
    private let studyVideoLabel: UILabel = {
        let label = UILabel()
        label.attributedText = NSAttributedString.create(withText: StringsProvider.string(forKey: .introVideoTitle),
                                                         fontStyle: .title,
                                                         colorType: .secondaryText)
        return label
    }()
    
    private lazy var playButton: UIButton = {
        let button = UIButton()
        button.autoSetDimensions(to: CGSize(width: 96.0, height: 96.0))
        button.addTarget(self, action: #selector(self.playButtonClicked), for: .touchUpInside)
        return button
    }()
    
    private lazy var continueButton: UIButton = {
        let button = UIButton()
        button.apply(style: ButtonTextStyleCategory.primaryBackground(customHeight: nil).style)
        button.setTitle(StringsProvider.string(forKey: .introVideoContinueButton), for: .normal)
        button.addTarget(self, action: #selector(self.continueButtonClicked), for: .touchUpInside)
        return button
    }()
    
    private lazy var closeButton: UIButton = {
        let button = UIButton()
        button.setImage(ImagePalette.templateImage(withName: .closeButtonTemplate), for: .normal)
        button.tintColor = ColorPalette.color(withType: .secondary)
        button.contentEdgeInsets = UIEdgeInsets(top: 8.0, left: 8.0, bottom: 8.0, right: 8.0)
        button.addTarget(self, action: #selector(self.closeButtonPressed), for: .touchUpInside)
        return button
    }()
    
    private let durationLabel: UILabel = {
        let label = UILabel()
        label.autoSetDimension(.width, toSize: 40.0)
        return label
    }()
    
    private lazy var slider: UISlider = {
        let slider = UISlider()
        slider.tintColor = ColorPalette.color(withType: .active)
        slider.setThumbImage(ImagePalette.image(withName: .circular), for: .normal)
        slider.setThumbImage(ImagePalette.image(withName: .circular), for: .highlighted)
        slider.addTarget(self, action: #selector(self.onSliderValChanged(slider:event:)), for: .valueChanged)
        return slider
    }()
    
    private var player: AVPlayer?
    private var playerEndTimeNotification: NSObjectProtocol?
    private var durationTime: Float64?
    private var isVideoPlaying: Bool = false {
        didSet {
            self.overlayView.isHidden = self.isVideoPlaying
        }
    }
    private var targetTime: CMTime?
    private var isVideoPlayedOnce: Bool = false
    private var timeObserver: Any?
    private var timer: Timer?
    
    private let navigator: AppNavigator
    private let analytics: AnalyticsService
    
    init() {
        self.navigator = Services.shared.navigator
        self.analytics = Services.shared.analytics
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.setupView()
        self.addVideoPlayer()
        self.addTapGestureToContainerView()
        self.updateProgressBar()
        self.configureTheViewElements()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.analytics.track(event: .recordScreen(screenName: AnalyticsScreens.studyVideo.rawValue,
                                                  screenClass: String(describing: type(of: self))))
        self.navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.primary(hidden: true).style)
        self.navigationItem.hidesBackButton = true
        self.addObserver()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        self.removeObserver()
    }
    
    deinit {
        self.removeObserver()
    }
    
    // MARK: - Actions
    
    @objc private func onSliderValChanged(slider: UISlider, event: UIEvent) {
        guard self.isVideoPlayedOnce else { return }
        
        if let touchEvent = event.allTouches?.first {
            switch touchEvent.phase {
            case .moved:
                self.player?.pause()
                let currentTime = CMTimeMakeWithSeconds(Float64((slider.value * Float(self.durationTime ?? 1))), preferredTimescale: 1)
                self.player?.seek(to: currentTime, toleranceBefore: CMTime.zero, toleranceAfter: CMTime.zero)
            case .ended:
                self.playButton.isHidden = true
                self.isVideoPlaying = true
                self.playButton.setImage(self.isVideoPlaying
                                            ? ImagePalette.image(withName: .videoPause)
                                            : ImagePalette.image(withName: .videoPlay),
                                         for: .normal)
                self.player?.play()
            default:
                break
            }
        }
    }
    
    @objc private func applicationDidBecomeActive() {
        if self.continueButton.isHidden {
            self.isVideoPlaying = true
            self.player?.play()
            self.playButton.setImage(ImagePalette.image(withName: .videoPause), for: .normal)
        } else {
            self.isVideoPlaying = false
            self.player?.pause()
            self.playButton.setImage(ImagePalette.image(withName: .videoPlay), for: .normal)
        }
    }
    
    @objc private func handleTapGesture() {
        self.playButton.isHidden = false
        self.timer?.invalidate()
        self.timer = Timer.scheduledTimer(timeInterval: 2,
                                          target: self,
                                          selector: #selector(self.hidePlayButtonAndSlider),
                                          userInfo: nil,
                                          repeats: false)
    }
    
    @objc private func hidePlayButtonAndSlider() {
        self.playButton.isHidden = self.isVideoPlaying
        self.timer = nil
    }
    
    @objc private func playButtonClicked() {
        self.isVideoPlaying = !self.isVideoPlaying
        self.isVideoPlayedOnce = true
        self.continueButton.isHidden = true
        self.studyVideoLabel.isHidden = true
        self.durationLabel.isHidden = false
        self.slider.isHidden = false
        self.playButton.setImage(isVideoPlaying
                                    ? ImagePalette.image(withName: .videoPause)
                                    : ImagePalette.image(withName: .videoPlay),
                                 for: .normal)
        if !self.isVideoPlaying {
            self.player?.pause()
            self.playButton.isHidden = false
        } else {
            self.player?.play()
            self.timer?.invalidate()
            self.timer = Timer.scheduledTimer(timeInterval: 2,
                                              target: self,
                                              selector: #selector(self.hidePlayButtonAndSlider),
                                              userInfo: nil,
                                              repeats: false)
        }
    }
    
    @objc private func continueButtonClicked() {
        self.navigateForward()
    }
    
    @objc private func closeButtonPressed() {
        self.navigateForward()
    }
    
    // MARK: - Private Methods
    
    private func setupView() {
        
        self.view.addSubview(self.layerView)
        self.layerView.autoPinEdgesToSuperviewEdges()
        
        self.view.addSubview(self.overlayView)
        self.overlayView.autoPinEdgesToSuperviewEdges()
        
        self.view.addSubview(self.continueButton)
        self.continueButton.autoPinEdgesToSuperviewSafeArea(with: UIEdgeInsets(top: 0.0,
                                                                               left: Constants.Style.DefaultHorizontalMargins,
                                                                               bottom: 24.0,
                                                                               right: Constants.Style.DefaultHorizontalMargins),
                                                            excludingEdge: .top)
        
        self.view.addSubview(self.durationLabel)
        self.durationLabel.autoPinEdge(toSuperviewEdge: .leading, withInset: 24.0)
        self.durationLabel.autoAlignAxis(.horizontal, toSameAxisOf: self.continueButton)
        
        self.view.addSubview(self.slider)
        self.slider.autoPinEdge(toSuperviewEdge: .trailing, withInset: 16.0)
        self.slider.autoAlignAxis(.horizontal, toSameAxisOf: self.durationLabel)
        self.slider.autoPinEdge(.leading, to: .trailing, of: self.durationLabel, withOffset: 16.0)
        
        self.view.addSubview(self.playButton)
        self.playButton.autoCenterInSuperview()
        
        self.view.addSubview(self.studyVideoLabel)
        self.studyVideoLabel.autoAlignAxis(toSuperviewAxis: .vertical)
        self.playButton.autoPinEdge(.top, to: .bottom, of: self.studyVideoLabel, withOffset: 32.0)
        
        self.view.addSubview(self.closeButton)
        self.closeButton.autoPinEdge(toSuperviewSafeArea: .top, withInset: 8.0)
        self.closeButton.autoPinEdge(toSuperviewEdge: .leading, withInset: Constants.Style.DefaultHorizontalMargins - 8.0)
    }
    
    private func configureTheViewElements() {
        self.studyVideoLabel.text = StringsProvider.string(forKey: .introVideoTitle)
        self.continueButton.setTitle(StringsProvider.string(forKey: .introVideoContinueButton), for: .normal)
        
        self.slider.isHidden = true
        self.durationLabel.isHidden = true
        self.playButton.isHidden = false
        self.playButton.setImage(ImagePalette.image(withName: .videoPlay), for: .normal)
    }
    
    private func addVideoPlayer() {
        guard let videoUrl = Constants.Resources.IntroVideoUrl else { return }
        
        let asset = AVAsset(url: videoUrl)
        let duration = asset.duration
        self.durationTime = CMTimeGetSeconds(duration)
        self.player = AVPlayer(url: videoUrl)
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback)
            do {
                try AVAudioSession.sharedInstance().setActive(true)
            } catch let error as NSError {
                debugPrint(error.localizedDescription)
            }
        } catch let error as NSError {
            debugPrint(error.localizedDescription)
        }
        let playerLayer = AVPlayerLayer(player: self.player)
        playerLayer.videoGravity = .resizeAspect
        playerLayer.backgroundColor = UIColor.black.cgColor
        playerLayer.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        self.player?.seek(to: .zero)
        self.layerView.layer.addSublayer(playerLayer)
    }
    
    private func addObserver() {
        self.addPlayerObserver()
        self.addApplicationDidBecomeActiveObserver()
    }
    
    private func addApplicationDidBecomeActiveObserver() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.applicationDidBecomeActive),
                                               name: UIApplication.didBecomeActiveNotification,
                                               object: nil)
    }
    
    private func addPlayerObserver() {
        self.playerEndTimeNotification = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime,
                                                                                object: self.player?.currentItem,
                                                                                queue: .main,
                                                                                using: { [weak self] _ in
                                                                                    self?.navigateForward()
                                                                                })
    }
    
    private func removePlayerObserver() {
        if let timeObserver = self.timeObserver { self.player?.removeTimeObserver(timeObserver) }
        guard let playerEndTimeNotification = self.playerEndTimeNotification else { return }
        NotificationCenter.default.removeObserver(playerEndTimeNotification)
    }
    
    private func removeObserver() {
        self.removePlayerObserver()
        NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    private func addTapGestureToContainerView() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.handleTapGesture))
        self.layerView.addGestureRecognizer(tapGesture)
    }
    
    private func navigateForward() {
        self.removePlayer()
        self.slider.value = 1.0
        self.navigator.onIntroVideoCompleted(presenter: self)
    }
    
    private func removePlayer() {
        self.player?.pause()
        self.player = nil
    }
    
    private func updateProgressBar() {
        let interval = CMTimeMakeWithSeconds(1 / 30.0, preferredTimescale: Int32(NSEC_PER_SEC))
        self.timeObserver = self.player?.addPeriodicTimeObserver(forInterval: interval, queue: nil) { [weak self] time in
            let minutes = Int(CMTimeGetSeconds(time) / 60)
            let seconds = Int(CMTimeGetSeconds(time).truncatingRemainder(dividingBy: 60))
            let text = String(format: "%02d:%02d", minutes, seconds)
            self?.durationLabel.attributedText = NSAttributedString.create(withText: text,
                                                                           fontStyle: .header3,
                                                                           colorType: .secondaryText)
            guard let durationTime = self?.durationTime else { return }
            self?.slider.value = Float((CMTimeGetSeconds(time) / durationTime))
        }
    }
}
