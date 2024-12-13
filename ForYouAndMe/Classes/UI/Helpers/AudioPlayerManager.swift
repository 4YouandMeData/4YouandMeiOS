//
//  AudioPlayerManager.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 13/12/24.
//

import Foundation
import AVFoundation

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
    
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var audioSession: AVAudioSession = AVAudioSession.sharedInstance()
    private var audioFileURL: URL?
    private var playbackTimer: Timer?
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    
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
    
    /// Pause the currently playing audio
    func pauseAudio() {
        guard state == .playing else { return }
        audioPlayer?.pause()
        stopPlaybackTimer()
        transition(to: .paused)
        delegate?.didPausePlaying()
    }
    
    /// Resume the paused audio
    func resumeAudio() {
        guard state == .paused else { return }
        audioPlayer?.play()
        startPlaybackTimer()
        transition(to: .playing)
        delegate?.didResumePlaying()
    }
    
    /// Stop audio playback
    func stopAudio() {
        switch state {
        case .playing, .paused:
            audioPlayer?.stop()
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
    
    /// Set up the audio recorder with proper settings
    private func setupAudioRecorder() throws {
        let fileName = "audio_\(UUID().uuidString).m4a"
        let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        audioFileURL = documentDirectory.appendingPathComponent(fileName)
        
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
    private func playAudio(from url: URL) {
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
    
    /// Start a timer to update playback progress
    private func startPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.audioPlayer else { return }
            self.delegate?.didUpdatePlaybackTime(currentTime: player.currentTime, totalTime: player.duration)
        }
    }
    
    /// Stop the playback timer
    private func stopPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
    
    /// Start a timer to update recording time
    private func startRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.recordingStartTime else { return }
            let elapsedTime = Date().timeIntervalSince(startTime)
            self.delegate?.didUpdateRecordingTime(elapsedTime: elapsedTime)
        }
    }
    
    /// Stop the recording timer
    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
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
        transition(to: .idle)
        stopPlaybackTimer()
        delegate?.didFinishPlaying(success: flag)
    }
}
