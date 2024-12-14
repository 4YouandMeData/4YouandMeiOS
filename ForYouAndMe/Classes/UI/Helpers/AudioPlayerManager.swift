// AudioPlayerManager.swift
// Pods
//
// Created by Giuseppe Lapenta on 13/12/24.
//

import Foundation
import AVFoundation

protocol AudioPlayerManagerDelegate: AnyObject {
    func didStartRecording()
    func didFinishRecording(fileURL: URL?, duration: TimeInterval?, error: Error?)
    func didStartPlaying()
    func didPausePlaying()
    func didResumePlaying()
    func didFinishPlaying(success: Bool)
    func didEncounterError(error: AudioPlayerError)
    func didUpdatePlaybackTime(currentTime: TimeInterval, totalTime: TimeInterval)
    func didUpdateRecordingTime(elapsedTime: TimeInterval)
}

enum AudioPlayerError: Error {
    case recordingUnavailable
    case playbackUnavailable
    case invalidFileURL
    case audioSessionSetupFailed
}

/// Enum representing the state of the audio manager
enum AudioPlayerState {
    case idle
    case recording
    case playing
    case paused
}

class AudioPlayerManager: NSObject {
    
    // MARK: - Properties
    
    weak var delegate: AudioPlayerManagerDelegate?
    
    static let audioFilenamePrefix = "Audio"
    
    private let audioExtension = "m4a"
    
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var avPlayer: AVPlayer?
    private var audioSession: AVAudioSession = AVAudioSession.sharedInstance()
    private var audioFileURL: URL?
    private var playbackTimer: Timer?
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    private var streamingEndObserver: NSObjectProtocol?
    
    /// Current state of the audio manager
    private(set) var state: AudioPlayerState = .idle
    
    // MARK: - Public Methods
    
    /// Configure the audio session for recording and playback
    func setupAudioSession() throws {
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
        } catch {
            throw AudioPlayerError.audioSessionSetupFailed
        }
    }
    
    /// Handle tap logic based on the current state
    func handleTap() {
        switch state {
        case .idle:
            startRecording()
        case .recording:
            stopRecording()
        case .playing:
            pauseAudio()
        case .paused:
            resumeAudio()
        }
    }
    
    /// Play the recorded audio if available
    func playRecordedAudio() {
        guard let url = audioFileURL else {
            delegate?.didEncounterError(error: .invalidFileURL)
            return
        }
        playAudio(from: url)
    }

    /// Play audio from a remote URL or local URL
    func playAudio(from url: URL) {
        if url.isFileURL {
            playLocalAudio(from: url)
        } else {
            playRemoteAudio(from: url)
        }
    }
    
    /// Pause the currently playing audio
    func pauseAudio() {
        switch state {
        case .playing:
            audioPlayer?.pause()
            avPlayer?.pause()
            stopPlaybackTimer()
            transition(to: .paused)
            delegate?.didPausePlaying()
        default:
            break
        }
    }
    
    /// Resume the paused audio
    func resumeAudio() {
        switch state {
        case .paused:
            if let player = audioPlayer {
                player.play()
            } else if let player = avPlayer {
                player.play()
            }
            startPlaybackTimer()
            transition(to: .playing)
            delegate?.didResumePlaying()
        default:
            break
        }
    }
    
    /// Stop audio playback
    func stopAudio() {
        switch state {
        case .playing, .paused:
            audioPlayer?.stop()
            avPlayer?.pause()
            stopPlaybackTimer()
            transition(to: .idle)
            delegate?.didFinishPlaying(success: true)
        default:
            break
        }
    }
    
    // MARK: - Private Methods
    
    /// Transition to a new state
    private func transition(to newState: AudioPlayerState) {
        state = newState
    }
    
    private func setOutputFileURL() throws -> URL {
        let outputFileName = "\(AudioPlayerManager.audioFilenamePrefix)"
        var isDir: ObjCBool = false
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: Constants.Note.NoteResultURL.path, isDirectory: &isDir) {
            try fileManager.createDirectory(atPath: Constants.Note.NoteResultURL.path,
                                            withIntermediateDirectories: false,
                                            attributes: nil)
        }
        let fileURL = Constants.Note.NoteResultURL.appendingPathComponent(outputFileName).appendingPathExtension(self.audioExtension)
        return fileURL
    }
    
    /// Set up the audio recorder with proper settings
    private func setupAudioRecorder() throws {
        audioFileURL = try self.setOutputFileURL()
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        audioRecorder = try AVAudioRecorder(url: audioFileURL!, settings: settings)
        audioRecorder?.delegate = self
    }
    
    /// Start recording audio
    private func startRecording() {
        guard state == .idle else { return }
        
        do {
            try setupAudioRecorder()
            audioRecorder?.record()
            recordingStartTime = Date()
            transition(to: .recording)
            delegate?.didStartRecording()
            startRecordingTimer()
        } catch {
            delegate?.didEncounterError(error: .recordingUnavailable)
        }
    }
    
    /// Stop recording audio
    private func stopRecording() {
        guard state == .recording else { return }
        audioRecorder?.stop()
        recordingStartTime = nil
        stopRecordingTimer()
        transition(to: .idle)
    }
    
    /// Play audio from a local URL
    private func playLocalAudio(from url: URL) {
        guard state == .idle else { return }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.play()
            transition(to: .playing)
            delegate?.didStartPlaying()
            startPlaybackTimer()
        } catch {
            delegate?.didEncounterError(error: .playbackUnavailable)
        }
    }
    
    /// Play audio from a remote URL
    private func playRemoteAudio(from url: URL) {
        guard state == .idle || state == .paused else { return }
        
        if avPlayer == nil || avPlayer?.currentItem?.asset != AVURLAsset(url: url) {
            avPlayer = AVPlayer(url: url)
            addStreamingEndObserver()
        } else {
            avPlayer?.seek(to: .zero)
        }
        avPlayer?.play()
        transition(to: .playing)
        delegate?.didStartPlaying()
        startPlaybackTimerForAVPlayer()
    }
    
    /// Add observer for streaming end
    private func addStreamingEndObserver() {
        streamingEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: avPlayer?.currentItem,
            queue: .main) { [weak self] _ in
            self?.handleStreamingEnd()
        }
    }
    
    /// Handle streaming end
    private func handleStreamingEnd() {
        stopPlaybackTimer()
        transition(to: .idle)
        delegate?.didFinishPlaying(success: true)
    }
    
    /// Start a timer to update playback progress
    private func startPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.audioPlayer else { return }
            self.delegate?.didUpdatePlaybackTime(currentTime: player.currentTime, totalTime: player.duration)
        }
    }

    private func startPlaybackTimerForAVPlayer() {
        playbackTimer?.invalidate()
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let currentItem = self.avPlayer?.currentItem else { return }
            let currentTime = CMTimeGetSeconds(currentItem.currentTime())
            let totalTime = CMTimeGetSeconds(currentItem.duration)
            if !currentTime.isNaN && !totalTime.isNaN {
                self.delegate?.didUpdatePlaybackTime(currentTime: currentTime, totalTime: totalTime)
            }
        }
    }

    private func stopPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    private func startRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.recordingStartTime else { return }
            let elapsedTime = Date().timeIntervalSince(startTime)
            self.delegate?.didUpdateRecordingTime(elapsedTime: elapsedTime)
        }
    }

    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }

    deinit {
        stopPlaybackTimer()
        stopRecordingTimer()
        if let observer = streamingEndObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

// MARK: - AVAudioRecorderDelegate
extension AudioPlayerManager: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if flag {
            // Calculate duration of the recorded audio
            let duration = calculateAudioDuration(url: audioFileURL)
            delegate?.didFinishRecording(fileURL: audioFileURL, duration: duration, error: nil)
        } else {
            delegate?.didEncounterError(error: .recordingUnavailable)
        }
    }

    /// Calculate the duration of an audio file
    private func calculateAudioDuration(url: URL?) -> TimeInterval? {
        guard let url = url else { return nil }
        do {
            let audioPlayer = try AVAudioPlayer(contentsOf: url)
            return audioPlayer.duration
        } catch {
            return nil
        }
    }
}

// MARK: - AVAudioPlayerDelegate
extension AudioPlayerManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        stopPlaybackTimer()
        transition(to: .idle)
        delegate?.didFinishPlaying(success: flag)
    }
}
