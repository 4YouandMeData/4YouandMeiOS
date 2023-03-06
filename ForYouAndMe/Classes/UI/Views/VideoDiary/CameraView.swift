//
//  CameraView.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 27/08/2020.
//

import Foundation
import AVFoundation
import UIKit
import EVGPUImage2


protocol CameraViewDelegate: AnyObject {
    func hasFinishedRecording(fileURL: URL?, error: Error?)
    func hasCaptureSessionErrorOccurred(error: CaptureSessionError)
    func hasCaptureOutputErrorOccurred(error: CaptureOutputError)
    func didFinishMergingVideo(mergedVideoURL: URL?)
    func hasVideoMergingErrorOccurred(error: VideoMergingError)
}

enum FlashMode {
    case off
    case on
}

enum FilterMode {
    case off
    case on
}

enum CaptureSessionError: Error {
    case captureSessionIsMissing
    case invalidOperation
    case noCamerasAvailable
    case cameraNotAuthorized
    case micNotAuthorized
}

enum CaptureOutputError: Error {
    case noCaptureOutputDetected
    case noOutputFilePathDetected
}

enum VideoMergingError: Error {
    case failedToLoadAudioTrack
    case failedToLoadVideoTrack
    case failedToCreatePathForMergedVideo
    case failedToExportVideo
    case failedToHandleMergeFileExtension
}

extension AVFileType {
    var extensionName: String? {
        switch self {
        case .mp4: return "mp4"
        default: return nil
        }
    }
}

class CameraView: UIView {
    
    static let videoFilenamePrefix = "Video"
    private static let cameraSessionQueue = "4youandme.prepareCameraSession"
    
    weak var delegate: CameraViewDelegate?
    
    var recordedVideoExtension = ""
    var flashMode = FlashMode.off
    var filterMode = FilterMode.off
    var allVideoURLs: [URL] = []
    //var previewLayer: AVCaptureVideoPreviewLayer?
    var renderView: RenderView = RenderView()

    var mergedFileType = AVFileType.mp4
    private var captureSession: AVCaptureSession?
    private var frontCamera: AVCaptureDevice?
    private var rearCamera: AVCaptureDevice?
    private(set) var currentCameraPosition: AVCaptureDevice.Position?
    private var currentCameraInput: AVCaptureDeviceInput?
    private var captureOutput: AVCaptureMovieFileOutput?
    private var outputFileURL: URL?
    private var isCameraInitialized: Bool = false
    
    private var mergedFileName = ""
    
    // ---------- CAMERA FILTERS ----------
    let saturationFilter = SaturationAdjustment()
    let adaptiveThresholdFilter = AdaptiveThreshold() //threesold filter
    var videoCamera: Camera? = nil // instance of "filtered" camera preview

    
    init() {
        super.init(frame: .zero)
        self.initFilteredCamera()
        self.prepareCameraView()
        self.addObservers()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    // MARK: - Public Methods
    func switchCamera() throws {
        if let currentCameraPosition = self.currentCameraPosition, let captureSession = self.captureSession, captureSession.isRunning {
            captureSession.beginConfiguration()
            if currentCameraPosition == .front {
                try self.switchTo(camera: self.rearCamera)
                self.currentCameraPosition = .back
            } else {
                try self.switchTo(camera: self.frontCamera)
                self.currentCameraPosition = .front
                self.flashMode = .off
            }
            captureSession.commitConfiguration()
        } else {
            throw CaptureSessionError.captureSessionIsMissing
        }
    }
    
    func setOutputFileURL(fileURL: URL? = nil) throws {
        if let fileURL = fileURL {
            self.outputFileURL = fileURL
            self.allVideoURLs.append(fileURL)
        } else {
            guard let fileURL = try self.returnDocumentsDirectoryFile(fileName: Self.videoFilenamePrefix,
                                                                      fileExtension: self.recordedVideoExtension) else {
                                                                        throw VideoMergingError.failedToCreatePathForMergedVideo
            }
            self.outputFileURL = fileURL
        }
    }
    
    func startRecording() {
        guard let movieFileOutput = self.captureOutput else {
            self.delegate?.hasCaptureOutputErrorOccurred(error: CaptureOutputError.noCaptureOutputDetected)
            return
        }
        
        if !movieFileOutput.isRecording {
            guard let outputFileURL = self.outputFileURL else {
                self.delegate?.hasCaptureOutputErrorOccurred(error: CaptureOutputError.noOutputFilePathDetected)
                return
            }

            movieFileOutput.startRecording(to: outputFileURL, recordingDelegate: self)
        }
    }
    
    func stopRecording() {
        guard let movieFileOutput = self.captureOutput else {
            self.delegate?.hasCaptureOutputErrorOccurred(error: CaptureOutputError.noCaptureOutputDetected)
            return
        }

        if movieFileOutput.isRecording {
            movieFileOutput.stopRecording()
        }
    }
    
    func toggleFlash() throws {
        if let currentCameraPosition = self.currentCameraPosition, currentCameraPosition == .back, let rearCamera = self.rearCamera {
            self.withDeviceLock(on: rearCamera) { (rearCamera) in
                if rearCamera.isTorchAvailable { // Check for exception
                    if self.flashMode == .off {
                        if rearCamera.isTorchModeSupported(.on) {
                            rearCamera.torchMode = .on
                            self.flashMode = .on
                        }
                    } else {
                        if rearCamera.isTorchModeSupported(.off) {
                            rearCamera.torchMode = .off
                            self.flashMode = .off
                        }
                    }
                }
            }
        }
    }
    
    // enable - disable filters
    func toggleFilters() throws {
        if let currentCameraPosition = self.currentCameraPosition, currentCameraPosition == .back, let rearCamera = self.rearCamera {
            self.withDeviceLock(on: rearCamera) { (rearCamera) in
                if rearCamera.isTorchAvailable { // Check for exception
                    if self.filterMode == .off {
                        if rearCamera.isTorchModeSupported(.on) {
                            rearCamera.torchMode = .on
                            self.filterMode = .on
                        }
                    } else {
                        if rearCamera.isTorchModeSupported(.off) {
                            rearCamera.torchMode = .off
                            self.filterMode = .off
                        }
                    }
                }
            }
        }
    }
     
    func updateVideoPreviewLayerFrame() {
        //self.previewLayer?.frame = self.bounds
        self.renderView.frame = self.bounds
        print("call: updateVideoPreviewLayerFrame")
    }
    
    func mergeRecordedVideos() {
        var totalTime = CMTimeMake(value: 0, timescale: 0)
        let composition = AVMutableComposition()
        guard let videoTrack = composition.addMutableTrack(withMediaType: .video,
                                                           preferredTrackID: kCMPersistentTrackID_Invalid) else { return }
        
        guard let audioTrack = composition.addMutableTrack(withMediaType: .audio,
                                                           preferredTrackID: kCMPersistentTrackID_Invalid) else { return }
        
        guard let mergeExtensionName = self.mergedFileType.extensionName else {
            assertionFailure("Unexpected extension type. Add it to AVFileType extension")
            self.delegate?.hasVideoMergingErrorOccurred(error: VideoMergingError.failedToHandleMergeFileExtension)
            return
        }
        
        for videoURL in self.allVideoURLs {
            let asset = AVAsset(url: videoURL)
            guard let assetVideoTrack = asset.tracks(withMediaType: .video).first else {
                self.delegate?.hasVideoMergingErrorOccurred(error: VideoMergingError.failedToLoadVideoTrack)
                return
            }
            
            videoTrack.preferredTransform = assetVideoTrack.preferredTransform
            let range = CMTimeRangeMake(start: CMTime.zero, duration: asset.duration)
            
            do {
                try videoTrack.insertTimeRange(range, of: assetVideoTrack, at: totalTime)
                guard let assetAudioTrack = asset.tracks(withMediaType: .audio).first else {
                    self.delegate?.hasVideoMergingErrorOccurred(error: VideoMergingError.failedToLoadAudioTrack)
                    return
                }
                
                do {
                    try audioTrack.insertTimeRange(range, of: assetAudioTrack, at: totalTime)
                    totalTime = CMTimeAdd(totalTime, asset.duration)
                } catch {
                    self.delegate?.hasVideoMergingErrorOccurred(error: VideoMergingError.failedToLoadAudioTrack)
                }
            } catch {
                self.delegate?.hasVideoMergingErrorOccurred(error: VideoMergingError.failedToLoadVideoTrack)
            }
        }
        
        let mergedFileURL: URL?
        self.mergedFileName = "\(Self.videoFilenamePrefix)_\(Date.currentDateInMilliSeconds())"
        do {
            mergedFileURL = try self.returnDocumentsDirectoryFile(fileName: self.mergedFileName,
                                                                  fileExtension: mergeExtensionName)
            if let mergedFileURL = mergedFileURL, FileManager.default.fileExists(atPath: mergedFileURL.path) {
                try FileManager.default.removeItem(at: mergedFileURL)
            }
            self.exportVideo(composition: composition, mergedFileURL: mergedFileURL)
        } catch {
            self.delegate?.hasVideoMergingErrorOccurred(error: VideoMergingError.failedToCreatePathForMergedVideo)
        }
    }
    
    // MARK: - Private Methods
    
    private func exportVideo(composition: AVMutableComposition, mergedFileURL: URL?) {
        let exportPreset = AVAssetExportPresetHighestQuality
        AVAssetExportSession.determineCompatibility(ofExportPreset: exportPreset,
                                                    with: composition,
                                                    outputFileType: self.mergedFileType) { [weak self] compatible in
            if compatible {
                guard let exporter = AVAssetExportSession(asset: composition, presetName: exportPreset) else {
                    self?.delegate?.hasVideoMergingErrorOccurred(error: VideoMergingError.failedToExportVideo)
                    return
                }
                
                exporter.outputURL = mergedFileURL
                exporter.outputFileType = self?.mergedFileType
                exporter.shouldOptimizeForNetworkUse = true
                exporter.fileLengthLimit = Constants.Misc.VideoDiaryMaxFileSize
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
            } else {
                self?.delegate?.hasVideoMergingErrorOccurred(error: VideoMergingError.failedToExportVideo)
            }
        }
    }
    
    private func returnDocumentsDirectoryFile(fileName: String, fileExtension: String) throws -> URL? {
        let fileURL = Constants.Task.VideoResultURL.appendingPathComponent(fileName).appendingPathExtension(fileExtension)
        return fileURL
    }
    
    private func isHardwareAuthorized(block: () -> Void) {
        if (AVCaptureDevice.authorizationStatus(for: .video) == .authorized),
            (AVCaptureDevice.authorizationStatus(for: .audio) == .authorized) {
            block()
        }
    }
    
    private func addObservers() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.willEnterForeground),
                                               name: UIApplication.willEnterForegroundNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.didEnterBackground),
                                               name: UIApplication.didEnterBackgroundNotification,
                                               object: nil)
    }
    
    private func prepareCameraView() {
        DispatchQueue(label: Self.cameraSessionQueue).async { [weak self] in
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
                        //self?.captureSession?.startRunning()
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
    
    private func createCaptureSession() {
        self.captureSession = AVCaptureSession()
        self.captureSession?.sessionPreset = Constants.Misc.VideoDiaryCaptureSessionPreset
    }
    
    private func configureCaptureDevices() throws {
        let session = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .unspecified)
        let cameras = session.devices
        if !cameras.isEmpty {
            for camera in cameras {
                if camera.position == .back {
                    self.rearCamera = camera
                } else if camera.position == .front {
                    self.frontCamera = camera
                }
            }
        } else {
            throw CaptureSessionError.noCamerasAvailable
        }
    }
    
    private func configureDeviceInputs() throws {
        guard let captureSession = self.captureSession else {
            throw CaptureSessionError.captureSessionIsMissing
        }
        
        captureSession.beginConfiguration()
        // Because we can have only one camera as input
        if let frontCamera = self.frontCamera {
            let captureInput = try AVCaptureDeviceInput(device: frontCamera)
            self.currentCameraInput = captureInput
            if captureSession.canAddInput(captureInput) {
                captureSession.addInput(captureInput)
            }
            self.currentCameraPosition = .front
        } else if let rearCamera = self.rearCamera {
            let captureInput = try AVCaptureDeviceInput(device: rearCamera)
            self.currentCameraInput = captureInput
            if captureSession.canAddInput(captureInput) {
                captureSession.addInput(captureInput)
            }
            self.currentCameraPosition = .back
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
    
    private func configureOutput() throws {
        guard let captureSession = self.captureSession else {
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
    
    
    private func addCameraPreviewLayer() throws {
        do {
            guard self.captureSession != nil else { throw CaptureSessionError.captureSessionIsMissing }
            self.adaptiveThresholdFilter.blurRadiusInPixels = 1.0
            self.adaptiveThresholdFilter.addTarget(self.renderView)
            self.videoCamera?.addTarget(self.adaptiveThresholdFilter)
            self.videoCamera?.startCapture() // start GPUImage camera preview filtering
        } catch {
            fatalError("Could not initialize rendering pipeline: \(error)")
        }
                
        DispatchQueue.main.async {
            self.renderView.frame = self.bounds // update gpuimage:renderview bounds
            self.addSubview(self.renderView) // add gpuimage's camera preview view to current view
        }
    }
    
    private func switchTo(camera: AVCaptureDevice?) throws {
        guard let captureSession = self.captureSession,
            let camera = camera,
            let currentCameraInput = self.currentCameraInput,
            captureSession.inputs.contains(currentCameraInput) else {
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
    
    private func withDeviceLock(on device: AVCaptureDevice, block: (AVCaptureDevice) -> Void) {
        do {
            try device.lockForConfiguration()
            block(device)
            device.unlockForConfiguration()
        } catch {
            debugPrint("can't acquire lock")
        }
    }
    
    private func checkForAuthorization(completion: @escaping (CaptureSessionError?) -> Void) {
        self.checkForCameraPermissions(completion: completion)
    }
    
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
            self.checkForMicPermissions(completion: completion)
        }
    }
    
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
    
    private func startSession() {
        if let captureSession = self.captureSession, !captureSession.isRunning {
            DispatchQueue(label: Self.cameraSessionQueue).async {
                captureSession.startRunning()
            }
        }
    }
    
    private func stopSession() {
        if let captureSession = self.captureSession, captureSession.isRunning {
            captureSession.stopRunning()
        }
    }
    
    // MARK: - Actions
    
    @objc private func willEnterForeground() {
        self.checkForAuthorization(completion: { [weak self] (error) in
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
        self.stopSession()
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate

extension CameraView: AVCaptureFileOutputRecordingDelegate {
    
    func fileOutput(_ output: AVCaptureFileOutput,
                    didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection],
                    error: Error?) {
        Async.mainQueue {
            // If an error occurs, remove this video URL from the array so that the merging does not fail
            if error != nil {
                self.allVideoURLs.removeObject(outputFileURL)
            }
            self.delegate?.hasFinishedRecording(fileURL: outputFileURL, error: error)
        }
    }
}



// Extension used to enable utility GPUImage methods
extension CameraView {
    
    // Initialization of GPUImage Camera preview instance
    func initFilteredCamera(){
        do {
            videoCamera = try Camera(sessionPreset:.hd1920x1080, location:.backFacing)
            videoCamera!.runBenchmark = true
        } catch {
            videoCamera = nil
            print("Couldn't initialize camera with error: \(error)")
        }
    }
}
