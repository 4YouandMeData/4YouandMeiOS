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
    var renderView: RenderView = RenderView()
    var ovalMask: UIView!
    
    var mergedFileType = AVFileType.mp4
    private var frontCamera: AVCaptureDevice?
    private var rearCamera: AVCaptureDevice?
    private(set) var currentCameraPosition: AVCaptureDevice.Position?
    private var outputFileURL: URL?
    private var isCameraInitialized: Bool = false
    
    private var mergedFileName = ""
    
    // ---------- CAMERA FILTERS ----------
    let saturationFilter = SaturationAdjustment()
    let adaptiveThresholdFilter = SobelEdgeDetection() // threesold filter
    let colorInversionFilter = ColorInversion() // color inversion
    let contrastFilter = ContrastAdjustment()
    
    var videoCamera: Camera! // instance of "filtered" camera preview
    // Camera recording
    var movieOutput: MovieOutput?
    var isRecording = false

    init() {
        super.init(frame: .zero)
        self.prepareCameraView()
        self.addObservers()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Public Methods
    func switchCamera() throws {
        
        if currentCameraPosition == .front {
            self.currentCameraPosition = .back
        } else {
            self.currentCameraPosition = .front
            self.flashMode = .off
        }
        self.reinitializeCamera()
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
    
    func startRecording(delete: Bool = true) {
        if delete {
            do {
                try FileManager.default.removeItem(at: self.outputFileURL!)
            } catch {
                print("Couldn't initialize movie, error: \(error)")
            }
        }
        
        do {
            let movieSize = Size(width: 1080, height: 1920)
            self.movieOutput = try MovieOutput(URL: self.outputFileURL!, size: movieSize, liveVideo: true)
            videoCamera.audioEncodingTarget = movieOutput
            self.isRecording = true
            saturationFilter --> movieOutput!
            movieOutput!.startRecording()
        } catch {
            print("Couldn't start movie recording, error: \(error)")

        }
    }
    
    func stopRecording() {
        movieOutput?.finishRecording {
            self.isRecording = false
            self.videoCamera.audioEncodingTarget = nil
            self.movieOutput = nil
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
        self.filterMode = self.filterMode == .on ? .off : .on
        /* if let camera = self.videoCamera {
         camera.stopCapture()
         self.requireCameraFilters()
         camera.startCapture()
         } */
        self.reinitializeCamera()
    }
    
    func updateVideoPreviewLayerFrame() {
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
        AppNavigator.pushProgressHUD()
        DispatchQueue(label: Self.cameraSessionQueue).async { [weak self] in
            self?.checkForAuthorization(completion: { (error) in
                if let error = error {
                    Async.mainQueue { [weak self] in
                         self?.delegate?.hasCaptureSessionErrorOccurred(error: error)
                    }
                } else {
                    do {
                        // Everything in async. Delegate the error
                        
                        try self?.addCameraPreviewLayer()
                        try self?.configureCaptureDevices()
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            AppNavigator.popProgressHUD()
        }
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
                    // self?.startSession()
                }
            }
        })
        
    }
    
    @objc private func didEnterBackground() {
        // self.stopSession()
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
    
    // Add Camera Preview
    private func addCameraPreviewLayer() throws {
        
        DispatchQueue.main.async {
            do {
                let cameraDirection: PhysicalCameraLocation = self.currentCameraPosition == .front ? .frontFacing : .backFacing
                self.videoCamera = try Camera(sessionPreset: .hd1920x1080, location: cameraDirection)

                self.requireCameraFilters()
                self.videoCamera?.startCapture() // start GPUImage camera preview filtering
            } catch {
                self.videoCamera = nil
                
                fatalError("Could not initialize rendering pipeline: \(error)")
            }
            
            if self.ovalMask == nil {
                let ovalRadius = self.bounds.width/2 - 10
                self.ovalMask = self.createOverlay(radius: ovalRadius )
            } else {
                self.ovalMask.removeFromSuperview()
            }
            self.renderView.frame = self.bounds // update gpuimage:renderview bounds
            self.renderView.removeFromSuperview()
            self.addSubview(self.renderView) // add gpuimage's camera preview view to current view
            self.addSubview(self.ovalMask) // oval mask
            self.setNeedsDisplay()
            self.layoutIfNeeded()
            
        }
    }
    
    // Definition of current filter
    func requireCameraFilters() {
        self.videoCamera.removeAllTargets()
        self.adaptiveThresholdFilter.removeAllTargets()
        self.saturationFilter.removeAllTargets()
        self.contrastFilter.removeAllTargets()
        self.colorInversionFilter.removeAllTargets()
        
        if filterMode == .on {
            self.saturationFilter.saturation = 1.0
            adaptiveThresholdFilter.edgeStrength = 0.8
            self.contrastFilter.contrast =  1.4
            videoCamera --> saturationFilter --> adaptiveThresholdFilter --> colorInversionFilter --> contrastFilter --> renderView
        } else {
            self.saturationFilter.saturation = 1.0
            videoCamera --> saturationFilter --> renderView
    
        }
        
        if(isRecording && movieOutput != nil ){ // Recover capture session
            saturationFilter --> movieOutput!  
            movieOutput!.startRecording()
        }
    }
    
    // Reinitialization of camera filters : stop -> remove all targets -> init camera -> add to parent view
    func reinitializeCamera() {
        if isRecording {
            stopRecording()
        }
        do {
            self.videoCamera.stopCapture()
            self.videoCamera.removeAllTargets()
            self.videoCamera = nil
            
            try self.addCameraPreviewLayer() // add preview layer on this view
            
            if isRecording { // recover recording session
                self.startRecording(delete: false)
            }
        } catch {
            print("Couldn't reinitialize camera with error: \(error)")
        }
    }
    
    // Oval mask
    func createOverlay(radius: CGFloat) -> UIView {
        let overlayView = UIView(frame: self.frame)
        overlayView.alpha = 0.6
        overlayView.backgroundColor = UIColor.black
        
        // Create a path with the rectangle in it.
        let path = CGMutablePath()
        // let offsetX = 30
        let widthMax = self.frame.width/1.1
        let heightMax = self.frame.height/1.4
        
        let originX = Int(self.frame.width)/2 - Int(widthMax)/2
        let originY = Int(self.frame.height)/2 - Int(heightMax)/2 - 30
        
        let rectangle = CGRect(x: CGFloat(originX), y: CGFloat(originY), width: widthMax, height: heightMax)
        path.addEllipse(in: rectangle)
        
        path.addRect(CGRect(x: 0, y: 0, width: overlayView.frame.width, height: overlayView.frame.height))
        
        let maskLayer = CAShapeLayer()
        maskLayer.backgroundColor = UIColor.black.cgColor
        maskLayer.path = path
        maskLayer.fillRule = CAShapeLayerFillRule.evenOdd
        
        // Release the path since it's not covered by ARC.
        overlayView.layer.mask = maskLayer
        overlayView.clipsToBounds = true
        
        return overlayView
    }
}
