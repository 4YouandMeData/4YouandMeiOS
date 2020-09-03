//
//  EHPlayerView.swift
//  Crohns
//
//  Created by Y Media Labs on 04/11/19.
//  Copyright © 2019 Y Media Labs. All rights reserved.
//

import Foundation
import UIKit
import AVKit

protocol EHPlayerViewDelegate: class {
    func hasFinishedPlaying()
    func tapGestureDidStart()
    func tapGestureWillEnd()
    func sliderValueDidChange()
}

/// Subclass of UIView that supports video playing from local and remote URL, pausing and seeking.
class EHPlayerView: UIView {
    
    static let hideSliderThumbWithDelay: Bool = false
    
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
    
    fileprivate var durationTime: Float64?
    fileprivate var timeObserver: Any?
    fileprivate var playerEndTimeNotification: NSObjectProtocol?
    fileprivate var timer: Timer?
    
    weak var delegate: EHPlayerViewDelegate?
    var player: AVPlayer?
    var contentView: UIView?
    var playerLayer: AVPlayerLayer?
    var videoURL: URL? {
        didSet {
            self.addVideoPlayer()
            self.updateProgressBar()
        }
    }
    
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
    
    // MARK: - Private Methods
    
    private func setupUI() {
        slider.setThumbImage(ImagePalette.image(withName: .circular), for: .normal)
        slider.setThumbImage(ImagePalette.image(withName: .circular), for: .highlighted)
        slider.addTarget(self, action: #selector(onSliderValChanged(slider:event:)), for: .valueChanged)
        addPlayerObserver()
    }
    
    /// Method to add the observer to observe if the video has finished playing.
    private func addPlayerObserver() {
        playerEndTimeNotification = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player?.currentItem, queue: .main) { [weak self] (_) in
            self?.player?.seek(to: .zero)
            self?.delegate?.hasFinishedPlaying()
        }
    }
    
    /// Method to remove both the observers added.
    private func removePlayerObserver() {
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
        guard let playerEndTimeNotification = playerEndTimeNotification else { return }
        NotificationCenter.default.removeObserver(playerEndTimeNotification)
    }
    
    /// Method to add a tap gesture to the layerView.
    private func addTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTapGesture(_:)))
        layerView.addGestureRecognizer(tapGesture)
    }
    
    /// Method to handle the tap action.
    @objc func handleTapGesture(_ sender: UITapGestureRecognizer) {
        self.delegate?.tapGestureDidStart()
        if Self.hideSliderThumbWithDelay {
            self.slider.setThumbImage(ImagePalette.image(withName: .circular), for: .normal)
            self.slider.setThumbImage(ImagePalette.image(withName: .circular), for: .highlighted)
            self.slider.isUserInteractionEnabled = true
            self.timer?.invalidate()
            self.timer = Timer.scheduledTimer(timeInterval: 2, target: self, selector: #selector(self.hideSlider), userInfo: nil, repeats: false)
        }
    }
    
    /// Method to handle the slider value changed action.
    @objc private func onSliderValChanged(slider: UISlider, event: UIEvent) {
        if let touchEvent = event.allTouches?.first {
            switch touchEvent.phase {
            case .moved :
                player?.pause()
                let currentTime = CMTimeMakeWithSeconds(Float64(slider.value * Float(durationTime ?? 1)), preferredTimescale: CMTimeScale(NSEC_PER_SEC))
                player?.seek(to: currentTime, toleranceBefore: CMTime.zero, toleranceAfter: CMTime.zero)
            case .ended:
                delegate?.sliderValueDidChange()
                player?.play()
            default:
                break
            }
        }
    }
    
    /// Method to hide the slider's thumb image.
    @objc private func hideSlider() {
        slider.setThumbImage(ImagePalette.image(withName: .clearCircular), for: .normal)
        slider.isUserInteractionEnabled = false
        delegate?.tapGestureWillEnd()
        timer = nil
    }
    
    /// Method to add the video player to the layerView.
    private func addVideoPlayer() {
        guard let videoURL = videoURL else { return }
        
        let asset = AVAsset(url: videoURL)
        let duration = asset.duration
        durationTime = CMTimeGetSeconds(duration)
        player = AVPlayer(url: videoURL)
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
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.frame = self.bounds
        player?.seek(to: .zero)
        layerView.layer.addSublayer(playerLayer)
        slider.isHidden = false
        durationLabel.isHidden = false
        self.addTapGesture()
    }
    
    /// Method to add an observer to update the progress bar for the video.
    private func updateProgressBar() {
        timeObserver = player?.addPeriodicTimeObserver(forInterval: CMTimeMakeWithSeconds(1 / 30.0, preferredTimescale: Int32(NSEC_PER_SEC)), queue: nil) { [weak self] time in
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
    
    private func scheduleSliderHide() {
        self.timer?.invalidate()
        self.timer = Timer.scheduledTimer(timeInterval: 2, target: self, selector: #selector(self.hideSlider), userInfo: nil, repeats: false)
    }
    
    // MARK: - Public Methods
    
    /// Method to play the video.
    func playVideo() {
        guard let player = player else { return }
        
        player.play()
        if Self.hideSliderThumbWithDelay {
            self.scheduleSliderHide()
        }
    }
    
    /// Method to pause the video.
    func pauseVideo() {
        guard let player = player else { return }

        player.pause()
        timer?.invalidate()
    }
}
