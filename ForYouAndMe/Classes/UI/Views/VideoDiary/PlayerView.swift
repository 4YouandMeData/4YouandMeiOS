//
//  PlayerView.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 27/08/2020.
//

import Foundation
import UIKit
import AVKit

protocol PlayerViewDelegate: AnyObject {
    func hasFinishedPlaying()
    func tapGestureDidStart()
    func tapGestureWillEnd()
    func sliderValueDidChange()
}

class PlayerView: UIView {
    
    private static let hideSliderThumbWithDelay: TimeInterval? = nil
    
    weak var delegate: PlayerViewDelegate?
    
    var player: AVPlayer?
    var contentView: UIView?
    var playerLayer: AVPlayerLayer?
    var videoURL: URL? {
        didSet {
            self.addVideoPlayer()
            self.updateProgressBar()
        }
    }
    
    private let layerView: UIView = {
        let view = UIView()
        return view
    }()
    
    private let durationLabel: UILabel = {
        let label = UILabel()
        label.autoSetDimension(.width, toSize: 40.0)
        return label
    }()
    
    private lazy var slider: UISlider = {
        let slider = UISlider()
        slider.tintColor = ColorPalette.color(withType: .active)
        slider.addTarget(self, action: #selector(self.onSliderValChanged(slider:event:)), for: .valueChanged)
        return slider
    }()
    
    private var durationTime: Float64?
    private var timeObserver: Any?
    private var playerEndTimeNotification: NSObjectProtocol?
    private var timer: Timer?
    
    init() {
        super.init(frame: .zero)
        
        self.addSubview(self.layerView)
        self.layerView.autoPinEdgesToSuperviewSafeArea(with: .zero, excludingEdge: .top)
        self.layerView.autoPinEdge(toSuperviewEdge: .top)
        
        self.addSubview(self.durationLabel)
        self.durationLabel.autoPinEdge(toSuperviewEdge: .leading, withInset: 16.0)
        self.durationLabel.autoPinEdge(toSuperviewSafeArea: .bottom, withInset: 12.0)
        
        self.addSubview(self.slider)
        self.slider.autoPinEdge(toSuperviewEdge: .trailing, withInset: 16.0)
        self.slider.autoAlignAxis(.horizontal, toSameAxisOf: self.durationLabel)
        self.slider.autoPinEdge(.leading, to: .trailing, of: self.durationLabel, withOffset: 16.0)
        
        self.setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.removePlayerObserver()
    }
    
    // MARK: - Public Methods
    
    /// Method to play the video.
    func playVideo() {
        guard let player = player else { return }
        
        player.play()
        if let hideDelay = Self.hideSliderThumbWithDelay {
            self.scheduleSliderHide(withDelay: hideDelay)
        }
    }
    
    /// Method to pause the video.
    func pauseVideo() {
        guard let player = player else { return }

        player.pause()
        timer?.invalidate()
    }
    
    // MARK: - Private Methods
    
    private func setupUI() {
        self.slider.setThumbImage(ImagePalette.image(withName: .circular), for: .normal)
        self.slider.setThumbImage(ImagePalette.image(withName: .circular), for: .highlighted)
        self.slider.addTarget(self, action: #selector(self.onSliderValChanged(slider:event:)), for: .valueChanged)
        self.addPlayerObserver()
    }
    
    private func addPlayerObserver() {
        self.playerEndTimeNotification = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime,
                                                                                object: self.player?.currentItem,
                                                                                queue: .main) { [weak self] _ in
            self?.player?.seek(to: .zero)
            self?.delegate?.hasFinishedPlaying()
        }
    }
    
    private func removePlayerObserver() {
        if let timeObserver = self.timeObserver {
            self.player?.removeTimeObserver(timeObserver)
        }
        guard let playerEndTimeNotification = self.playerEndTimeNotification else { return }
        NotificationCenter.default.removeObserver(playerEndTimeNotification)
    }
    
    private func addTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.handleTapGesture(_:)))
        self.layerView.addGestureRecognizer(tapGesture)
    }
    
    private func addVideoPlayer() {
        guard let videoURL = self.videoURL else { return }
        
        let asset = AVAsset(url: videoURL)
        let duration = asset.duration
        self.durationTime = CMTimeGetSeconds(duration)
        self.player = AVPlayer(url: videoURL)
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
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.frame = self.bounds
        self.player?.seek(to: .zero)
        self.layerView.layer.addSublayer(playerLayer)
        self.slider.isHidden = false
        self.durationLabel.isHidden = false
        self.addTapGesture()
    }
    
    private func updateProgressBar() {
        let interval = CMTimeMakeWithSeconds(1 / 30.0, preferredTimescale: Int32(NSEC_PER_SEC))
        self.timeObserver = self.player?.addPeriodicTimeObserver(forInterval: interval, queue: nil) { [weak self] time in
            let minutes = Int(CMTimeGetSeconds(time) / 60)
            let seconds = Int(CMTimeGetSeconds(time).truncatingRemainder(dividingBy: 60))
            let text = String(format: "%02d:%02d", minutes, seconds)
            self?.durationLabel.attributedText = NSAttributedString.create(withText: text,
                                                                           fontStyle: .paragraph,
                                                                           colorType: .secondaryText)
            guard let durationTime = self?.durationTime else { return }
            self?.slider.value = Float((CMTimeGetSeconds(time) / durationTime))
        }
    }
    
    private func scheduleSliderHide(withDelay delay: TimeInterval) {
        self.timer?.invalidate()
        self.timer = Timer.scheduledTimer(timeInterval: delay,
                                          target: self,
                                          selector: #selector(self.hideSlider),
                                          userInfo: nil,
                                          repeats: false)
    }
    
    // MARK: - Actions
    
    @objc private func handleTapGesture(_ sender: UITapGestureRecognizer) {
        self.delegate?.tapGestureDidStart()
        if let hideDelay = Self.hideSliderThumbWithDelay {
            self.slider.setThumbImage(ImagePalette.image(withName: .circular), for: .normal)
            self.slider.setThumbImage(ImagePalette.image(withName: .circular), for: .highlighted)
            self.slider.isUserInteractionEnabled = true
            self.scheduleSliderHide(withDelay: hideDelay)
        }
    }
    
    @objc private func onSliderValChanged(slider: UISlider, event: UIEvent) {
        if let touchEvent = event.allTouches?.first {
            switch touchEvent.phase {
            case .moved :
                self.player?.pause()
                let currentTime = CMTimeMakeWithSeconds(Float64(slider.value * Float(self.durationTime ?? 1)),
                                                        preferredTimescale: CMTimeScale(NSEC_PER_SEC))
                self.player?.seek(to: currentTime, toleranceBefore: CMTime.zero, toleranceAfter: CMTime.zero)
            case .ended:
                self.delegate?.sliderValueDidChange()
                self.player?.play()
            default:
                break
            }
        }
    }
    
    @objc private func hideSlider() {
        self.slider.setThumbImage(ImagePalette.image(withName: .clearCircular), for: .normal)
        self.slider.isUserInteractionEnabled = false
        self.delegate?.tapGestureWillEnd()
        self.timer = nil
    }
}
