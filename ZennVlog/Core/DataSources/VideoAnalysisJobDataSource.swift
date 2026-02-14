import AVFoundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import FirebaseStorage
import Foundation

protocol VideoAnalysisJobDataSourceProtocol: Sendable {
    func analyzeVideo(
        url: URL,
        mimeType: String,
        projectId: String?
    ) async throws -> VideoAnalysisResult
}

actor VideoAnalysisJobDataSource: VideoAnalysisJobDataSourceProtocol {

    // MARK: - Constants

    private let maxVideoDurationSeconds: Double = 180
    private let maxVideoSizeBytes: Int64 = 300 * 1024 * 1024

    // MARK: - Properties

    private let auth: Auth
    private let storage: Storage
    private let firestore: Firestore
    private let functions: Functions
    private let fileManager: FileManager

    // MARK: - Init

    init(
        auth: Auth = Auth.auth(),
        storage: Storage = Storage.storage(),
        firestore: Firestore = Firestore.firestore(),
        functions: Functions = Functions.functions(region: "asia-northeast1"),
        fileManager: FileManager = .default
    ) {
        self.auth = auth
        self.storage = storage
        self.firestore = firestore
        self.functions = functions
        self.fileManager = fileManager
    }

    // MARK: - VideoAnalysisJobDataSourceProtocol

    func analyzeVideo(
        url: URL,
        mimeType: String,
        projectId: String? = nil
    ) async throws -> VideoAnalysisResult {
        let user = try await ensureSignedInAnonymously()
        try validateLocalVideo(url: url)
        let duration = try await videoDuration(url: url)
        try validateDuration(duration)

        await postProgress(status: .queued, progress: 0, jobId: nil)

        let uploaded = try await uploadVideo(
            at: url,
            mimeType: mimeType,
            userId: user.uid
        )
        await postProgress(status: .processing, progress: 0.1, jobId: nil)

        let jobId = try await createJob(
            storagePath: uploaded.storagePath,
            mimeType: mimeType,
            durationSec: duration,
            projectId: projectId
        )

        return try await waitForCompletion(jobId: jobId, expectedUserId: user.uid)
    }

    // MARK: - Private Methods

    private func ensureSignedInAnonymously() async throws -> User {
        if let currentUser = auth.currentUser {
            return currentUser
        }

        return try await withCheckedThrowingContinuation { continuation in
            auth.signInAnonymously { result, error in
                if let error {
                    continuation.resume(throwing: GeminiRepositoryError.requestFailed(underlying: error))
                    return
                }
                guard let user = result?.user else {
                    continuation.resume(
                        throwing: GeminiRepositoryError.requestFailed(
                            underlying: NSError(
                                domain: "VideoAnalysisJobDataSource",
                                code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "Anonymous sign-in failed"]
                            )
                        )
                    )
                    return
                }
                continuation.resume(returning: user)
            }
        }
    }

    private func validateLocalVideo(url: URL) throws {
        guard url.isFileURL else {
            throw GeminiRepositoryError.videoAnalysisFailed(
                underlying: NSError(
                    domain: "VideoAnalysisJobDataSource",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Video URL must be a local file URL"]
                )
            )
        }

        guard fileManager.fileExists(atPath: url.path) else {
            throw GeminiRepositoryError.videoAnalysisFailed(
                underlying: NSError(
                    domain: "VideoAnalysisJobDataSource",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Local video file not found"]
                )
            )
        }

        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        let fileSize = (attributes[.size] as? NSNumber)?.int64Value ?? 0
        guard fileSize > 0 else {
            throw GeminiRepositoryError.videoAnalysisFailed(
                underlying: NSError(
                    domain: "VideoAnalysisJobDataSource",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Video file is empty"]
                )
            )
        }

        guard fileSize <= maxVideoSizeBytes else {
            throw GeminiRepositoryError.videoAnalysisFailed(
                underlying: NSError(
                    domain: "VideoAnalysisJobDataSource",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Video file is larger than 300MB"]
                )
            )
        }
    }

    private func videoDuration(url: URL) async throws -> Double {
        let asset = AVURLAsset(url: url)
        let cmDuration = try await asset.load(.duration)
        let seconds = CMTimeGetSeconds(cmDuration)
        guard seconds.isFinite else {
            throw GeminiRepositoryError.videoAnalysisFailed(
                underlying: NSError(
                    domain: "VideoAnalysisJobDataSource",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid video duration"]
                )
            )
        }
        return seconds
    }

    private func validateDuration(_ duration: Double) throws {
        guard duration > 0 else {
            throw GeminiRepositoryError.videoAnalysisFailed(
                underlying: NSError(
                    domain: "VideoAnalysisJobDataSource",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Video duration must be positive"]
                )
            )
        }

        guard duration <= maxVideoDurationSeconds else {
            throw GeminiRepositoryError.videoAnalysisFailed(
                underlying: NSError(
                    domain: "VideoAnalysisJobDataSource",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Video duration exceeds 180 seconds"]
                )
            )
        }
    }

    private func uploadVideo(
        at url: URL,
        mimeType: String,
        userId: String
    ) async throws -> UploadedVideo {
        let ext = url.pathExtension.isEmpty ? "mp4" : url.pathExtension.lowercased()
        let path = "video-analysis-inputs/\(userId)/\(UUID().uuidString).\(ext)"
        let reference = storage.reference(withPath: path)

        let metadata = StorageMetadata()
        metadata.contentType = mimeType

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            reference.putFile(from: url, metadata: metadata) { uploadedMetadata, error in
                if let error {
                    continuation.resume(throwing: GeminiRepositoryError.requestFailed(underlying: error))
                    return
                }
                guard uploadedMetadata != nil else {
                    continuation.resume(
                        throwing: GeminiRepositoryError.requestFailed(
                            underlying: NSError(
                                domain: "VideoAnalysisJobDataSource",
                                code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "Upload metadata is missing"]
                            )
                        )
                    )
                    return
                }
                continuation.resume(returning: ())
            }
        }

        return UploadedVideo(storagePath: path)
    }

    private func createJob(
        storagePath: String,
        mimeType: String,
        durationSec: Double,
        projectId: String?
    ) async throws -> String {
        let callable = functions.httpsCallable("createVideoAnalysisJob")
        var payload: [String: Any] = [
            "storagePath": storagePath,
            "mimeType": mimeType,
            "durationSec": durationSec
        ]
        if let projectId {
            payload["projectId"] = projectId
        }

        let result: HTTPSCallableResult = try await withCheckedThrowingContinuation { continuation in
            callable.call(payload) { response, error in
                if let error {
                    continuation.resume(throwing: GeminiRepositoryError.requestFailed(underlying: error))
                    return
                }
                guard let response else {
                    continuation.resume(
                        throwing: GeminiRepositoryError.requestFailed(
                            underlying: NSError(
                                domain: "VideoAnalysisJobDataSource",
                                code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "Callable response is missing"]
                            )
                        )
                    )
                    return
                }
                continuation.resume(returning: response)
            }
        }

        guard let data = result.data as? [String: Any],
              let jobId = data["jobId"] as? String,
              !jobId.isEmpty else {
            throw GeminiRepositoryError.responseParseFailed(
                underlying: NSError(
                    domain: "VideoAnalysisJobDataSource",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Callable response does not contain jobId"]
                )
            )
        }

        return jobId
    }

    private func waitForCompletion(
        jobId: String,
        expectedUserId: String
    ) async throws -> VideoAnalysisResult {
        let ref = firestore.collection("video_analysis_jobs").document(jobId)

        return try await withCheckedThrowingContinuation { continuation in
            var listener: ListenerRegistration?
            var isResolved = false

            func resolveOnce(_ result: Result<VideoAnalysisResult, Error>) {
                guard !isResolved else { return }
                isResolved = true
                listener?.remove()
                switch result {
                case .success(let value):
                    continuation.resume(returning: value)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            listener = ref.addSnapshotListener { snapshot, error in
                if let error {
                    resolveOnce(.failure(GeminiRepositoryError.requestFailed(underlying: error)))
                    return
                }

                guard let data = snapshot?.data() else {
                    return
                }

                let owner = data["userId"] as? String ?? ""
                guard owner == expectedUserId else {
                    resolveOnce(
                        .failure(
                            GeminiRepositoryError.videoAnalysisFailed(
                                underlying: NSError(
                                    domain: "VideoAnalysisJobDataSource",
                                    code: -1,
                                    userInfo: [NSLocalizedDescriptionKey: "Job ownership mismatch"]
                                )
                            )
                        )
                    )
                    return
                }

                let status = JobStatus(rawValue: data["status"] as? String ?? "") ?? .queued
                let progress = self.parseDouble(data["progress"]) ?? 0

                Task {
                    await self.postProgress(status: status, progress: progress, jobId: jobId)
                }

                switch status {
                case .completed:
                    do {
                        let result = try self.parseResult(from: data)
                        resolveOnce(.success(result))
                    } catch {
                        resolveOnce(.failure(error))
                    }
                case .failed:
                    let message = (data["error"] as? [String: Any])?["message"] as? String
                    let fallbackMessage = message ?? "Video analysis job failed"
                    resolveOnce(
                        .failure(
                            GeminiRepositoryError.videoAnalysisFailed(
                                underlying: NSError(
                                    domain: "VideoAnalysisJobDataSource",
                                    code: -1,
                                    userInfo: [NSLocalizedDescriptionKey: fallbackMessage]
                                )
                            )
                        )
                    )
                case .queued, .processing:
                    break
                }
            }
        }
    }

    private func parseResult(from data: [String: Any]) throws -> VideoAnalysisResult {
        guard let result = data["result"] as? [String: Any],
              let segmentsRaw = result["segments"] as? [[String: Any]] else {
            throw GeminiRepositoryError.responseParseFailed(
                underlying: NSError(
                    domain: "VideoAnalysisJobDataSource",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Result segments are missing"]
                )
            )
        }

        let segments = try segmentsRaw.map { raw -> AnalyzedSegment in
            guard let start = parseDouble(raw["startSeconds"]),
                  let end = parseDouble(raw["endSeconds"]),
                  let description = raw["description"] as? String else {
                throw GeminiRepositoryError.responseParseFailed(
                    underlying: NSError(
                        domain: "VideoAnalysisJobDataSource",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Invalid segment format"]
                    )
                )
            }

            let confidence = parseDouble(raw["confidence"])
            let visualLabels = raw["visualLabels"] as? [String]

            return AnalyzedSegment(
                startSeconds: start,
                endSeconds: end,
                description: description,
                confidence: confidence,
                visualLabels: visualLabels
            )
        }.sorted { lhs, rhs in
            lhs.startSeconds < rhs.startSeconds
        }

        return VideoAnalysisResult(segments: segments)
    }

    private func parseDouble(_ value: Any?) -> Double? {
        if let value = value as? Double {
            return value
        }
        if let value = value as? Int {
            return Double(value)
        }
        if let value = value as? NSNumber {
            return value.doubleValue
        }
        if let value = value as? String {
            return Double(value)
        }
        return nil
    }

    private func postProgress(
        status: JobStatus,
        progress: Double,
        jobId: String?
    ) async {
        await MainActor.run {
            NotificationCenter.default.post(
                name: .videoAnalysisProgressDidUpdate,
                object: nil,
                userInfo: [
                    VideoAnalysisProgressUserInfoKey.status: status.rawValue,
                    VideoAnalysisProgressUserInfoKey.progress: max(0, min(progress, 1)),
                    VideoAnalysisProgressUserInfoKey.jobId: jobId ?? ""
                ]
            )
        }
    }
}

private struct UploadedVideo: Sendable {
    let storagePath: String
}

private enum JobStatus: String {
    case queued
    case processing
    case completed
    case failed
}

extension Notification.Name {
    static let videoAnalysisProgressDidUpdate = Notification.Name("videoAnalysisProgressDidUpdate")
}

enum VideoAnalysisProgressUserInfoKey {
    static let status = "status"
    static let progress = "progress"
    static let jobId = "jobId"
}
