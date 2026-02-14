//import AVFoundation
//import Photos
//import Combine
//
//final class CameraRecorderService: NSObject, ObservableObject {
//     let session = AVCaptureSession()
//    private let movieOutput = AVCaptureMovieFileOutput()
//    private let queue = DispatchQueue(label: "camera.recorder.queue")
//    
//    private var isConfigured = false
//    
//    // 録画完了通知（必要ならUI側で受ける）
//    var onFinished: ((URL) -> Void)?
//    var onError: ((Error) -> Void)?
//    
//    // プレビュー用に渡す
//    var captureSession: AVCaptureSession { session }
//    
//    func startSession() {
//        queue.async {
//            if self.session.isRunning { return }
//            if !self.isConfigured { self.configure() }
//            self.session.startRunning()
//        }
//    }
//    
//    func stopSession() {
//        queue.async {
//            if self.session.isRunning { self.session.stopRunning() }
//        }
//    }
//    
//    func startRecording() {
//        queue.async {
//            guard self.movieOutput.isRecording == false else { return }
//            let url = self.makeTempURL()
//            self.movieOutput.startRecording(to: url, recordingDelegate: self)
//        }
//    }
//    
//    func stopRecording() {
//        queue.async {
//            guard self.movieOutput.isRecording else { return }
//            self.movieOutput.stopRecording()
//        }
//    }
//    
//    // MARK: - Private
//    
//    private func configure() {
//        session.beginConfiguration()
//        session.sessionPreset = .high
//        
//        // input reset
//        session.inputs.forEach { session.removeInput($0) }
//        session.outputs.forEach { session.removeOutput($0) }
//        
//        // video only（マイクなし）
//        guard
//            let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
//            let input = try? AVCaptureDeviceInput(device: camera),
//            session.canAddInput(input)
//        else {
//            session.commitConfiguration()
//            return
//        }
//        session.addInput(input)
//        
//        guard session.canAddOutput(movieOutput) else {
//            session.commitConfiguration()
//            return
//        }
//        session.addOutput(movieOutput)
//        
//        session.commitConfiguration()
//        isConfigured = true
//    }
//    
//    private func makeTempURL() -> URL {
//        FileManager.default.temporaryDirectory
//            .appendingPathComponent("\(UUID().uuidString).mov")
//    }
//    
//    private func saveToCameraRoll(videoURL: URL) async throws {
//        try await PHPhotoLibrary.requestAuthorization(for: .addOnly).guardAuthorized()
//        
//        try await PHPhotoLibrary.shared().performChanges {
//            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
//        }
//    }
//}
//
//// MARK: - AVCaptureFileOutputRecordingDelegate
//extension CameraRecorderService: AVCaptureFileOutputRecordingDelegate {
//    func fileOutput(_ output: AVCaptureFileOutput,
//                    didFinishRecordingTo outputFileURL: URL,
//                    from connections: [AVCaptureConnection],
//                    error: Error?) {
//        
//        if let error {
//            DispatchQueue.main.async { self.onError?(error) }
//            return
//        }
//        
//        Task {
//            do {
//                try await saveToCameraRoll(videoURL: outputFileURL)
//                DispatchQueue.main.async { self.onFinished?(outputFileURL) }
//            } catch {
//                DispatchQueue.main.async { self.onError?(error) }
//            }
//        }
//    }
//}
//
//// MARK: - Helpers
//private extension PHAuthorizationStatus {
//    func guardAuthorized() throws {
//        if self == .authorized || self == .limited { return }
//        throw NSError(domain: "PhotoAuth", code: 1)
//    }
//}
