//
//  NoteVideoPlayerView.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 26/01/25.
//

import UIKit
import AVFoundation
import PureLayout

class NoteVideoPlayerView: UIView {
    
    // MARK: - Properties
    
    // AVPlayerLayer used to display video content
    private let playerLayer = AVPlayerLayer()
    
    // Slider for controlling playback position
    private let slider = UISlider()
    
    // AVPlayer instance
    private var player: AVPlayer?
    
    // Time observer token for removing observer when deinitialized
    private var timeObserverToken: Any?
    
    // Define a timeScale of 1 second (NSEC_PER_SEC)
    private let timeScale = CMTimeScale(NSEC_PER_SEC)
    
    /// The video URL to play. When set, it initializes a new AVPlayer and starts playback.
    var videoURL: URL? {
        didSet {
            if let url = videoURL {
                configurePlayer(with: url)
            }
        }
    }
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        // Add the AVPlayerLayer to the view's main layer
        layer.addSublayer(playerLayer)
        
        // Configure the slider
        slider.addTarget(self, action: #selector(sliderValueChanged(_:)), for: .valueChanged)
        
        // Add slider as subview
        addSubview(slider)
        
        // Set up constraints with PureLayout
        // Note: For CALayer (playerLayer) we will manage its frame in layoutSubviews()
        slider.autoPinEdge(toSuperviewEdge: .left, withInset: 16)
        slider.autoPinEdge(toSuperviewEdge: .right, withInset: 16)
        slider.autoPinEdge(toSuperviewEdge: .bottom, withInset: 16)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Calculate space for the slider at the bottom
        let sliderHeight: CGFloat = 40
        
        // Update playerLayer's frame so it doesn't overlap the slider
        // Since CALayer doesn't use Auto Layout, we manually set its frame here.
        playerLayer.frame = CGRect(
            x: 0,
            y: 0,
            width: bounds.width,
            height: bounds.height - sliderHeight - 16
        )
    }
    
    // MARK: - Player Configuration
    
    private func configurePlayer(with url: URL) {
        // Remove old time observer if exists
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        
        // Create a new AVPlayer
        let newPlayer = AVPlayer(url: url)
        playerLayer.player = newPlayer
        
        // Add a periodic time observer to update slider position according to playback
        let interval = CMTime(seconds: 1.0, preferredTimescale: timeScale)
        timeObserverToken = newPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] currentTime in
            guard let self = self else { return }
            guard let duration = newPlayer.currentItem?.duration.seconds, duration > 0 else { return }
            
            let currentSeconds = currentTime.seconds
            self.slider.value = Float(currentSeconds / duration)
        }
        
        // Keep a reference to the player
        self.player = newPlayer
    }
    
    // MARK: - Playback Control
    
    /// Public method to start or resume playback
    func playVideo() {
        player?.play()
    }
    
    /// Public method to pause playback
    func pauseVideo() {
        player?.pause()
    }
    
    // MARK: - Slider Action
    
    @objc private func sliderValueChanged(_ sender: UISlider) {
        guard let currentPlayer = player,
              let duration = currentPlayer.currentItem?.duration.seconds,
              duration > 0 else { return }
        
        // Calculate the new time based on slider value
        let newTime = Double(sender.value) * duration
        let seekTime = CMTime(seconds: newTime, preferredTimescale: timeScale)
        currentPlayer.seek(to: seekTime)
    }
    
    // MARK: - Deinitialization
    
    deinit {
        // Remove the time observer on deinit
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
    }
}
