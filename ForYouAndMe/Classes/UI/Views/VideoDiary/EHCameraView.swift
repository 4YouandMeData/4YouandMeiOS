//
//  EHCameraView.swift
//  Crohns
//
//  Created by Y Media Labs on 30/10/19.
//  Copyright © 2019 Y Media Labs. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation

typealias DispatchCancelableClosure = (_ cancel: Bool) -> Void

/// This class implements static functions for asynchronous clousers in main thread with and without delay. And provides function to cancel the closure.
class Async {
    
    ///  Use this method to delay the execution of code in mainthread, which will also returns a bool value closure to give a feesibility of cancelling the block at any point of time.
    ///
    /// - Parameters:
    ///     - time: Delay period in NSTimeInterval.
    ///     - closure: The block to submit to the target main dispatch_queue.
    /// - Returns: DispatchCancelableClosure - Can be stored and use to cancel the operation by calling a cancel_delay(_: ) method
    @discardableResult
    static func mainQueueWithDelay(_ time: TimeInterval, closure: @escaping () -> Void) -> DispatchCancelableClosure? {
        func dispatch_later(_ clsr: @escaping () -> Void) {
            DispatchQueue.main.asyncAfter(
                deadline: DispatchTime.now() + Double(Int64(time * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC), execute: clsr)
        }
        
        var theClousre: (() -> Void)? = closure
        var cancelableClosure: DispatchCancelableClosure?
        
        let delayedClosure: DispatchCancelableClosure = { cancel in
            if let theClousre = theClousre {
                if cancel == false {
                    DispatchQueue.main.async(execute: theClousre)
                }
            }
            theClousre = nil
            cancelableClosure = nil
        }
        
        cancelableClosure = delayedClosure
        
        dispatch_later {
            if let delayedClosure = cancelableClosure {
                delayedClosure(false)
            }
        }
        return cancelableClosure
    }
    
    ///  Use this method to cancel the execution of code in mainthread which is delayed.
    ///
    /// - Parameter closure: DispatchCancelableClosure which sends a signal to the execution block by sending some bool value to cancel the operation.
    static func cancelDelayedExecution(_ closure: DispatchCancelableClosure?) {
        if let closure = closure {
            closure(true)
        }
    }
    
    ///  Use this method to execute the code asynchronously in main queue without any delay.
    ///
    /// - Parameter closure: The block to submit to the target main dispatch_queue.
    static func mainQueue(_ closure: @escaping () -> Void) {
        DispatchQueue.main.async(execute: closure)
    }
    
}

extension Date {
    /// Converts the current date to milliseconds.
    ///
    /// - Returns: Milliseconds in double.
    static func currentDateInMilliSeconds() -> Double {
        return round(Date().timeIntervalSince1970 * 1000)
    }
}

public extension Array where Element: Equatable {
    
    ///  This method will return random element from array by getting random index value from count of the array.
    ///
    /// - Returns: Element - Returns the generic Element which can be typecasted.
    func randomItem() -> Element {
        let index = Int(UInt32(arc4random_uniform(UInt32(self.count))))
        return self[index]
    }
    
    ///  This method will fetch the list of elements upto specified index, if index is more than count, it will consider count as index.
    ///
    /// - Returns: Element - Returns the list of elements upto specific index.
    func takeElements(_ elementCount: Int) -> Array {
        if elementCount > count {
            return Array(self[0..<count])
        }
        return Array(self[0..<elementCount])
    }
    
    mutating func removeObject(_ object: Element) {
        if let index = firstIndex(of: object) {
            remove(at: index)
        }
    }
}

/// Enum with possible capture session errors
enum CaptureSessionError: Error {
    case captureSessionIsMissing
    case invalidOperation
    case noCamerasAvailable
    case cameraNotAuthorized
    case micNotAuthorized
}

/// Enum with possible flash modes for the back camera
enum FlashMode {
    case off
    case on
}

/// Enum with possible errors which occur while recording the video
enum CaptureOutputError: Error {
    case noCaptureOutputDetected
    case noOutputFilePathDetected
    
    var localizedDescription: String {
        return "Video Output failed"// TODO: Return error string
    }
}

/// Enum with possible errors which occur while merging the video
enum VideoMergingError: Error {
    case failedToLoadAudioTrack
    case failedToLoadVideoTrack
    case failedToCreatePathForMergedVideo
    case failedToExportVideo
    
    var localizedDescription: String {
        return "Video Merging failed"// TODO: Return error string
    }
}

protocol EHCameraViewDelegate: class {
    func hasFinishedRecording(fileURL: URL?, error: Error?)
    func hasCaptureSessionErrorOccurred(error: CaptureSessionError)
    func hasCaptureOutputErrorOccurred(error: CaptureOutputError)
    func didFinishMergingVideo(mergedVideoURL: URL?)
    func hasVideoMergingErrorOccurred(error: VideoMergingError)
}

/// Subclass of UIView that supports and implements all functionalities of video recording.
class EHCameraView: UIView {
    
    // MARK: - Private Variables
    
    private var captureSession: AVCaptureSession?
    private var frontCamera: AVCaptureDevice?
    private var rearCamera: AVCaptureDevice?
    private(set) var currentCameraPosition: AVCaptureDevice.Position?
    private var currentCameraInput: AVCaptureDeviceInput?
    private var captureOutput: AVCaptureMovieFileOutput?
    private var outputFileURL: URL?
    private var isCameraInitialized: Bool = false
    
    private var mergedFileName = ""
    private var mergedFileType = AVFileType.mp4
    private var isRecordingStopped = false
    var recordedVideoExtension = ""
    var flashMode = FlashMode.off
    var allVideoURLs: [URL] = []
    var previewLayer: AVCaptureVideoPreviewLayer?
    var mergedFileExtension = "mp4"
    weak var delegate: EHCameraViewDelegate?
    
    // MARK: - Constants
    
    let cameraSessionQueue = "com.ymedialabs.devteam.crohns.prepareCameraSession"
    
    init() {
        super.init(frame: .zero)
        
        prepareCameraView()
        addObservers()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Private Methods
    
    private func addObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(willEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }
    
    /// Method to initialize the camera view.
    private func prepareCameraView() {
        DispatchQueue(label: cameraSessionQueue).async { [weak self] in
            self?.checkForAuthorization(completion: { (error) in
                if let error = error {
                    Async.mainQueue { [weak self] in
                        self?.delegate?.hasCaptureSessionErrorOccurred(error: error)
                    }
                } else {
                    do {
                        // Everything in async. Delegate the error
                        self?.createCaptureSession()
                        try self?.addCameraPreviewLayer()
                        try self?.configureCaptureDevices()
                        try self?.configureDeviceInputs()
                        try self?.configureOutput()
                        self?.captureSession?.startRunning()
                        try self?.setOutputFileURL()
                        self?.isCameraInitialized = true
                    } catch let error {
                        Async.mainQueue { [weak self] in
                            if let error = error as? CaptureSessionError {
                                self?.delegate?.hasCaptureSessionErrorOccurred(error: error)
                            } else if let error = error as? CaptureOutputError {
                                self?.delegate?.hasCaptureOutputErrorOccurred(error: error)
                            }
                        }
                    }
                }
            })
        }
    }
    
    /// Method to initialize an AV Capture Session.
    private func createCaptureSession() {
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .hd1280x720
    }
    
    /// Method to search for the devices used for video recording like back camera and front camera and configure the respective devices.
    private func configureCaptureDevices() throws {
        let session = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .unspecified)
        let cameras = session.devices
        if !cameras.isEmpty {
            for camera in cameras {
                if camera.position == .back {
                    rearCamera = camera
                } else if camera.position == .front {
                    frontCamera = camera
                }
            }
        } else {
            throw CaptureSessionError.noCamerasAvailable
        }
    }
    
    /// Method to add camera and microphone as the capture inputs for the capture session. Default camera added will be the rear camera.
    private func configureDeviceInputs() throws {
        guard let captureSession = captureSession else {
            throw CaptureSessionError.captureSessionIsMissing
        }
        
        captureSession.beginConfiguration()
        //Because we can have only one camera as input        
        if let frontCamera = frontCamera {
            let captureInput = try AVCaptureDeviceInput(device: frontCamera)
            currentCameraInput = captureInput
            if captureSession.canAddInput(captureInput) {
                captureSession.addInput(captureInput)
            }
            currentCameraPosition = .front
        } else if let rearCamera = rearCamera {
            let captureInput = try AVCaptureDeviceInput(device: rearCamera)
            currentCameraInput = captureInput
            if captureSession.canAddInput(captureInput) {
                captureSession.addInput(captureInput)
            }
            currentCameraPosition = .back
        } else {
            throw CaptureSessionError.noCamerasAvailable
        }
        
        if let mic = AVCaptureDevice.default(for: .audio) {
            let captureMic = try AVCaptureDeviceInput(device: mic)
            if captureSession.canAddInput(captureMic) {
                captureSession.addInput(captureMic)
            }
        }
        captureSession.commitConfiguration()
    }
    
    /// Method to add a AVCaptureMovieFileOutput as the capture output for the capture session.
    private func configureOutput() throws {
        guard let captureSession = captureSession else {
            throw CaptureSessionError.captureSessionIsMissing
        }
        
        captureSession.beginConfiguration()
        let captureOutput = AVCaptureMovieFileOutput()
        if captureSession.canAddOutput(captureOutput) {
            captureSession.addOutput(captureOutput)
        }
        self.captureOutput = captureOutput
        captureSession.commitConfiguration()
    }
    
    /// Method to initialise the video preview layer and add it as a sublayer to the CameraView
    private func addCameraPreviewLayer() throws {
        guard let captureSession = self.captureSession else { throw CaptureSessionError.captureSessionIsMissing }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        previewLayer?.connection?.videoOrientation = .portrait
        DispatchQueue.main.async {
            self.previewLayer?.frame = self.bounds
            if let previewLayer = self.previewLayer {
                self.layer.addSublayer(previewLayer)
            }
        }
    }
    
    /// Method to switch to the specified camera.
    private func switchTo(camera: AVCaptureDevice?) throws {
        guard let captureSession = captureSession, let camera = camera, let currentCameraInput = currentCameraInput, captureSession.inputs.contains(currentCameraInput) else {
            throw CaptureSessionError.invalidOperation
        }
        
        captureSession.removeInput(currentCameraInput)
        self.currentCameraInput = try AVCaptureDeviceInput(device: camera)
        if let currentCameraInput = self.currentCameraInput {
            if captureSession.canAddInput(currentCameraInput) {
                captureSession.addInput(currentCameraInput)
            } else {
                throw CaptureSessionError.invalidOperation
            }
        }
    }
    
    /// This method requests exclusive access to the device’s hardware properties.
    /// 
    /// - Parameter device: device whose property should be accessed
    private func withDeviceLock(on device: AVCaptureDevice, block: (AVCaptureDevice) -> Void) {
        do {
            try device.lockForConfiguration()
            block(device)
            device.unlockForConfiguration()
        } catch {
            debugPrint("can't acquire lock")
        }
    }
    
    /// Method to check if permissions for camera and microphone are given and if not then show an alert to take the user to Settings.
    ///
    /// - Parameter completion: Returns any error occured while getting permissions for camera and microphone.
    private func checkForAuthorization(completion: @escaping (CaptureSessionError?) -> Void) {
        //Have to consider for iOS 12+ where changing settings will not kill the app.
        
        checkForCameraPermissions(completion: completion)
    }
    
    /// Method to check for camera permissions
    ///
    /// - Parameter completion: Returns the error occured while getting permissions for camera.
    private func checkForCameraPermissions(completion: @escaping (CaptureSessionError?) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] (granted) in
                if !granted {
                    completion(CaptureSessionError.cameraNotAuthorized)
                } else {
                    self?.checkForMicPermissions(completion: completion)
                }
            }
        case .denied:
            completion(CaptureSessionError.cameraNotAuthorized)
        default:
            checkForMicPermissions(completion: completion)
        }
    }
    
    /// Method to check for microphone permissions
    /// 
    /// - Parameter completion: Returns the error occured while getting permissions for microphone.
    private func checkForMicPermissions(completion: @escaping (CaptureSessionError?) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { (granted) in
                if !granted {
                    completion(CaptureSessionError.micNotAuthorized)
                } else {
                    completion(nil)
                }
            }
        case .denied:
            completion(CaptureSessionError.micNotAuthorized)
        default:
            completion(nil)
        }
    }
    
    /// Method to start the capture session if it exists and is not running.
    private func startSession() {
        if let captureSession = captureSession, !captureSession.isRunning {
            DispatchQueue(label: cameraSessionQueue).async {
                captureSession.startRunning()
            }
        }
    }
    
    /// Method to stop the capture session if it exists and is running
    private func stopSession() {
        if let captureSession = captureSession, captureSession.isRunning {
            captureSession.stopRunning()
        }
    }
    
    @objc private func willEnterForeground() {
        checkForAuthorization(completion: { [weak self] (error) in
            if let error = error {
                self?.delegate?.hasCaptureSessionErrorOccurred(error: error)
            } else {
                if let isCameraInitialized = self?.isCameraInitialized {
                    if !isCameraInitialized {
                        self?.prepareCameraView()
                    }
                }
                self?.isHardwareAuthorized {
                    self?.startSession()
                }
            }
        })
        
    }
    
    @objc private func didEnterBackground() {
        stopSession()
    }
    
    // MARK: - Public Methods
    
    /// Method to configure the video file extension type which will use for merging the videos and for export the video.
    func configureTheCameraAttributes() {
        if mergedFileExtension == "mp4" {
            mergedFileType = AVFileType.mp4
        } else if mergedFileExtension == "mov" {
            mergedFileType = AVFileType.mov
        }
    }
    
    /// Method to switch the camera between the front and the back camera.
    func switchCamera() throws {
        if let currentCameraPosition = currentCameraPosition, let captureSession = captureSession, captureSession.isRunning {
            captureSession.beginConfiguration()
            if currentCameraPosition == .front {
                try switchTo(camera: rearCamera)
                self.currentCameraPosition = .back
            } else {
                try switchTo(camera: frontCamera)
                self.currentCameraPosition = .front
                self.flashMode = .off
            }
            captureSession.commitConfiguration()
        } else {
            throw CaptureSessionError.captureSessionIsMissing
        }
    }
    
    /// Method to set the URL to store the video. Default is a file named Video.mov in the documents directory.
    ///
    /// - Parameter fileURL: URL to store the video
    func setOutputFileURL(fileURL: URL? = nil) throws {
        if let fileURL = fileURL {
            outputFileURL = fileURL
            allVideoURLs.append(fileURL)
        } else {
            guard let fileURL = try returnDocumentsDirectoryFile(fileName: "Video", fileExtension: recordedVideoExtension) else { throw VideoMergingError.failedToCreatePathForMergedVideo }
            outputFileURL = fileURL
        }
    }
    
    /// Method to start the recording of the video
    func startRecording() {
        isRecordingStopped = false
        guard let movieFileOutput = captureOutput else {
            delegate?.hasCaptureOutputErrorOccurred(error: CaptureOutputError.noCaptureOutputDetected)
            return
        }
        
        if !movieFileOutput.isRecording {
            guard let outputFileURL = outputFileURL else {
                delegate?.hasCaptureOutputErrorOccurred(error: CaptureOutputError.noOutputFilePathDetected)
                return
            }

            movieFileOutput.startRecording(to: outputFileURL, recordingDelegate: self)
        }
    }
    
    /// Method to stop the recording of the video
    func stopRecording() {
        isRecordingStopped = true
        guard let movieFileOutput = captureOutput else {
            delegate?.hasCaptureOutputErrorOccurred(error: CaptureOutputError.noCaptureOutputDetected)
            return
        }
        
        if movieFileOutput.isRecording {
            movieFileOutput.stopRecording()
        }
    }
    
    /// Method to toggle the flash of the back camera.
    func toggleFlash() throws {
        if let currentCameraPosition = currentCameraPosition, currentCameraPosition == .back, let rearCamera = rearCamera {
            withDeviceLock(on: rearCamera) { (rearCamera) in
                if rearCamera.isTorchAvailable { //check for exception
                    if flashMode == .off {
                        if rearCamera.isTorchModeSupported(.on) {
                            rearCamera.torchMode = .on
                            flashMode = .on
                        }
                    } else {
                        if rearCamera.isTorchModeSupported(.off) {
                            rearCamera.torchMode = .off
                            flashMode = .off
                        }
                    }
                }
            }
        }
    }
    
    /// Method to update the video preview layer frame 
    func updateVideoPreviewLayerFrame() {
        previewLayer?.frame = self.bounds
    }
    
    /// Method to merge the recorded videos into one video.
    func mergeRecordedVideos() {
        var totalTime = CMTimeMake(value: 0, timescale: 0)
        let composition = AVMutableComposition()
        guard let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else { return }
        
        guard let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else { return }
        
        for videoURL in allVideoURLs {
            let asset = AVAsset(url: videoURL)
            guard let assetVideoTrack = asset.tracks(withMediaType: .video).first else {
                delegate?.hasVideoMergingErrorOccurred(error: VideoMergingError.failedToLoadVideoTrack)
                return
            }
            
            videoTrack.preferredTransform = assetVideoTrack.preferredTransform
            do {
                try videoTrack.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: asset.duration), of: assetVideoTrack, at: totalTime)
                guard let assetAudioTrack = asset.tracks(withMediaType: .audio).first else {
                    delegate?.hasVideoMergingErrorOccurred(error: VideoMergingError.failedToLoadAudioTrack)
                    return
                }
                
                do {
                    try audioTrack.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: asset.duration), of: assetAudioTrack, at: totalTime)
                    totalTime = CMTimeAdd(totalTime, asset.duration)
                } catch {
                    delegate?.hasVideoMergingErrorOccurred(error: VideoMergingError.failedToLoadAudioTrack)
                }
            } catch {
                delegate?.hasVideoMergingErrorOccurred(error: VideoMergingError.failedToLoadVideoTrack)
            }
        }
        
        let mergedFileURL: URL?
        mergedFileName = "Video_\(Date.currentDateInMilliSeconds())"
        do {
            mergedFileURL = try returnDocumentsDirectoryFile(fileName: mergedFileName, fileExtension: mergedFileExtension)
            if let mergedFileURL = mergedFileURL, FileManager.default.fileExists(atPath: mergedFileURL.path) {
                try FileManager.default.removeItem(at: mergedFileURL)
            }
            exportVideo(composition: composition, mergedFileURL: mergedFileURL)
        } catch {
            delegate?.hasVideoMergingErrorOccurred(error: VideoMergingError.failedToCreatePathForMergedVideo)
        }
    }
    
    /// Method to export the video from the composition to a particular file type (using mp4 here)
    ///
    /// - Parameters:
    ///     - composition: The composition consisting of the merged videos
    ///     - mergedFileURL: The URL to store the exported video
    private func exportVideo(composition: AVMutableComposition, mergedFileURL: URL?) {
        AVAssetExportSession.determineCompatibility(ofExportPreset: AVAssetExportPresetPassthrough, with: composition, outputFileType: mergedFileType) { [weak self] (compatible) in
            if compatible {
                guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough) else { return }
                
                exporter.outputURL = mergedFileURL
                exporter.outputFileType = self?.mergedFileType
                exporter.shouldOptimizeForNetworkUse = true
                exporter.exportAsynchronously { [weak self] in
                    // To execute the result of exporting in the main thread
                    Async.mainQueue { [weak self] in
                        switch exporter.status {
                        case .completed:
                            self?.delegate?.didFinishMergingVideo(mergedVideoURL: mergedFileURL)
                        default:
                            self?.delegate?.hasVideoMergingErrorOccurred(error: VideoMergingError.failedToExportVideo)
                        }
                    }
                }
            }
        }
    }
    
    /// Method to return the URL of a file created in the documents directory
    /// 
    /// - Parameters:
    ///     - fileName: The name of the file to be created in the documents directory
    ///     - fileExtension: The extension of the file to be created in the documents directorys
    private func returnDocumentsDirectoryFile(fileName: String, fileExtension: String) throws -> URL? {
        let fileURL = Constants.Task.videoResultURL.appendingPathComponent(fileName).appendingPathExtension(fileExtension)
        return fileURL
    }
    
    /// Method to check if the permissions are provided for camera and microphone and execute a block if both the permissions are given
    ///
    /// - Parameter block: Block of code to execute if permissions are given
    func isHardwareAuthorized(block: () -> Void) {
        if (AVCaptureDevice.authorizationStatus(for: .video) == .authorized), (AVCaptureDevice.authorizationStatus(for: .audio) == .authorized) {
            block()
        }
    }
    
}

// MARK: - AVCaptureFileOutputRecordingDelegate

extension EHCameraView: AVCaptureFileOutputRecordingDelegate {
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        // If an error occurs, remove this video URL from the array so that the merging does not fail
        if error != nil {
            allVideoURLs.removeObject(outputFileURL)
        }
        delegate?.hasFinishedRecording(fileURL: outputFileURL, error: isRecordingStopped ? nil : error)
    }
}
