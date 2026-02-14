import Foundation
import AVFoundation
import Combine

final class CameraService: NSObject, ObservableObject {
    
    enum PermissionState {
        case unknown
        case authorized
        case deniedOrRestricted
    }
    
    let session = AVCaptureSession()
    
    @Published private(set) var permissionState: PermissionState = .unknown
    @Published private(set) var isRecording: Bool = false
    @Published private(set) var isReady: Bool = false
    @Published private(set) var isStartingRecording: Bool = false   // ✅追加
    
    var onRecordingFinished: ((URL, Double) -> Void)?
    
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private let movieOutput = AVCaptureMovieFileOutput()
    
    private var isConfigured = false
    private var isConfiguring = false
    
    // MARK: - Permission / Session
    
    func startIfNeeded() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .authorized:
            permissionState = .authorized
            configureAndStartSessionIfNeeded()
            
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    self.permissionState = granted ? .authorized : .deniedOrRestricted
                    if granted { self.configureAndStartSessionIfNeeded() }
                }
            }
            
        case .denied, .restricted:
            permissionState = .deniedOrRestricted
            
        @unknown default:
            permissionState = .deniedOrRestricted
        }
    }

    
    private func configureAndStartSessionIfNeeded() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            
            if self.session.isRunning {
                DispatchQueue.main.async { self.isReady = true }
                return
            }
            
            if self.isConfiguring { return }
            self.isConfiguring = true
            defer { self.isConfiguring = false }
            
            if !self.isConfigured {
                self.session.beginConfiguration()
                self.session.sessionPreset = .high
                
                for input in self.session.inputs { self.session.removeInput(input) }
                for output in self.session.outputs { self.session.removeOutput(output) }
                
                // Video only（マイク無し）
                guard
                    let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                    let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
                    self.session.canAddInput(videoInput)
                else {
                    self.session.commitConfiguration()
                    return
                }
                self.session.addInput(videoInput)
                
                guard self.session.canAddOutput(self.movieOutput) else {
                    self.session.commitConfiguration()
                    return
                }
                self.session.addOutput(self.movieOutput)
                
                self.session.commitConfiguration()
                self.isConfigured = true
            }
            
            self.session.startRunning()
            
            // isRunning を確認してから ready
            for _ in 0..<20 {
                if self.session.isRunning { break }
                usleep(50_000)
            }
            
            DispatchQueue.main.async {
                self.isReady = self.session.isRunning
            }
        }
    }
    
    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            
            // 録画中/開始中にセッションを止めない（競合防止）
            if self.movieOutput.isRecording || self.isStartingRecording {
                return
            }
            
            if self.session.isRunning {
                self.session.stopRunning()
            }
            
            DispatchQueue.main.async {
                self.isReady = false
            }
        }
    }
    
    // MARK: - Recording
    
    func startRecording() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard !self.movieOutput.isRecording else { return }
            
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("recording-\(UUID().uuidString).mov")
            
            print("startRecording url:", url)
            self.movieOutput.startRecording(to: url, recordingDelegate: self)
            
            DispatchQueue.main.async {
                self.isRecording = true
            }
        }
    }
    
    func stopRecording() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard self.movieOutput.isRecording else { return }
            self.movieOutput.stopRecording()
        }
    }
    
    // MARK: - Helpers
    
    private func makeTempMovieURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("recording-\(UUID().uuidString).mov")
    }
    
    private func setPermissionStateOnMain(_ state: PermissionState) {
        if Thread.isMainThread {
            permissionState = state
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.permissionState = state
            }
        }
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate

extension CameraService: AVCaptureFileOutputRecordingDelegate {
    
    // ✅ ここで「録画開始を確定」させる
    func fileOutput(_ output: AVCaptureFileOutput,
                    didStartRecordingTo fileURL: URL,
                    from connections: [AVCaptureConnection]) {
        DispatchQueue.main.async { [weak self] in
            self?.isStartingRecording = false
            self?.isRecording = true
        }
    }
    
    func fileOutput(_ output: AVCaptureFileOutput,
                    didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection],
                    error: Error?) {
        
        let durationSeconds: Double = {
            let asset = AVURLAsset(url: outputFileURL)
            let seconds = CMTimeGetSeconds(asset.duration)
            return seconds.isFinite ? seconds : 0
        }()
        
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isRecording = false
            self.isStartingRecording = false
            
            if let error {
                print("Recording failed:", error)
                return
            }
            
            self.onRecordingFinished?(outputFileURL, durationSeconds)
        }
    }
}
