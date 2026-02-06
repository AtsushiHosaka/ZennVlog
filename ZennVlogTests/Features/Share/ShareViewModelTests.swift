import Foundation
import Photos
import Testing
import UIKit
@testable import ZennVlog

@Suite("ShareViewModel Tests")
@MainActor
struct ShareViewModelTests {

    // MARK: - Test Helpers

    /// テスト用のモックProject作成
    private func createMockProject() -> Project {
        Project(
            id: UUID(),
            name: "テストプロジェクト",
            theme: "旅行",
            projectDescription: "テスト用の旅行Vlog"
        )
    }

    /// テスト用のモックURL作成
    private func createMockVideoURL() -> URL {
        URL(string: "mock://video/exported.mp4")!
    }

    /// テスト用のモック画像作成
    private func createMockThumbnail() -> UIImage {
        UIImage()
    }

    /// テスト用のViewModelを作成
    private func createViewModel(
        project: Project? = nil,
        exportedVideoURL: URL? = nil,
        thumbnailImage: UIImage? = nil,
        mockPhotoLibrary: MockPhotoLibraryService? = nil,
        mockActivityController: MockActivityControllerService? = nil
    ) -> (ShareViewModel, MockPhotoLibraryService, MockActivityControllerService) {
        let photoLibrary = mockPhotoLibrary ?? MockPhotoLibraryService()
        let activityController = mockActivityController ?? MockActivityControllerService()

        let viewModel = ShareViewModel(
            project: project ?? createMockProject(),
            exportedVideoURL: exportedVideoURL ?? createMockVideoURL(),
            thumbnailImage: thumbnailImage,
            photoLibrary: photoLibrary,
            activityController: activityController
        )

        return (viewModel, photoLibrary, activityController)
    }

    // MARK: - 初期状態のテスト

    @Test("初期状態が正しく設定される")
    func 初期状態が正しく設定される() {
        // Given
        let project = createMockProject()
        let videoURL = createMockVideoURL()
        let thumbnail = createMockThumbnail()

        // When
        let (viewModel, _, _) = createViewModel(
            project: project,
            exportedVideoURL: videoURL,
            thumbnailImage: thumbnail
        )

        // Then
        #expect(viewModel.project.id == project.id)
        #expect(viewModel.exportedVideoURL == videoURL)
        #expect(viewModel.thumbnailImage != nil)
        #expect(viewModel.isSaving == false)
        #expect(viewModel.saveSuccess == false)
        #expect(viewModel.errorMessage == nil)
    }

    // MARK: - 写真ライブラリ保存のテスト

    @Test("権限がauthorizedの場合、保存が成功する")
    func 権限がauthorizedの場合保存が成功する() async throws {
        // Given
        let (viewModel, mockPhotoLibrary, _) = createViewModel()
        mockPhotoLibrary.mockAuthorizationStatus = .authorized
        mockPhotoLibrary.shouldThrowError = false

        // When
        try await viewModel.saveToPhotoLibrary()

        // Then
        #expect(viewModel.saveSuccess == true)
        #expect(viewModel.isSaving == false)
        #expect(viewModel.errorMessage == nil)
        #expect(mockPhotoLibrary.saveCallCount == 1)
        #expect(mockPhotoLibrary.lastSavedURL == viewModel.exportedVideoURL)
    }

    @Test("権限がlimitedの場合も保存が成功する")
    func 権限がlimitedの場合も保存が成功する() async throws {
        // Given
        let (viewModel, mockPhotoLibrary, _) = createViewModel()
        mockPhotoLibrary.mockAuthorizationStatus = .limited
        mockPhotoLibrary.shouldThrowError = false

        // When
        try await viewModel.saveToPhotoLibrary()

        // Then
        #expect(viewModel.saveSuccess == true)
        #expect(viewModel.isSaving == false)
        #expect(viewModel.errorMessage == nil)
        #expect(mockPhotoLibrary.saveCallCount == 1)
    }

    @Test("権限がdeniedの場合、エラーがスローされる")
    func 権限がdeniedの場合エラーがスローされる() async {
        // Given
        let (viewModel, mockPhotoLibrary, _) = createViewModel()
        mockPhotoLibrary.mockAuthorizationStatus = .denied

        // When & Then
        await #expect(throws: ShareViewModelError.self) {
            try await viewModel.saveToPhotoLibrary()
        }

        #expect(viewModel.saveSuccess == false)
        #expect(viewModel.isSaving == false)
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.errorMessage?.contains("許可されていません") == true)
    }

    @Test("権限がnotDeterminedの場合、エラーがスローされる")
    func 権限がnotDeterminedの場合エラーがスローされる() async {
        // Given
        let (viewModel, mockPhotoLibrary, _) = createViewModel()
        mockPhotoLibrary.mockAuthorizationStatus = .notDetermined

        // When & Then
        await #expect(throws: ShareViewModelError.self) {
            try await viewModel.saveToPhotoLibrary()
        }

        #expect(viewModel.saveSuccess == false)
        #expect(viewModel.isSaving == false)
        #expect(viewModel.errorMessage != nil)
    }

    @Test("権限がrestrictedの場合、エラーがスローされる")
    func 権限がrestrictedの場合エラーがスローされる() async {
        // Given
        let (viewModel, mockPhotoLibrary, _) = createViewModel()
        mockPhotoLibrary.mockAuthorizationStatus = .restricted

        // When & Then
        await #expect(throws: ShareViewModelError.self) {
            try await viewModel.saveToPhotoLibrary()
        }

        #expect(viewModel.saveSuccess == false)
        #expect(viewModel.isSaving == false)
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.errorMessage?.contains("許可されていません") == true)
    }

    @Test("保存処理でエラーが発生した場合、エラーメッセージが設定される")
    func 保存処理でエラーが発生した場合エラーメッセージが設定される() async {
        // Given
        let (viewModel, mockPhotoLibrary, _) = createViewModel()
        mockPhotoLibrary.mockAuthorizationStatus = .authorized
        mockPhotoLibrary.shouldThrowError = true

        // When & Then
        await #expect(throws: Error.self) {
            try await viewModel.saveToPhotoLibrary()
        }

        #expect(viewModel.saveSuccess == false)
        #expect(viewModel.isSaving == false)
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.errorMessage?.contains("保存に失敗しました") == true)
    }

    @Test("保存完了後、isSavingがfalseになる")
    func 保存完了後isSavingがfalseになる() async throws {
        // Given
        let (viewModel, mockPhotoLibrary, _) = createViewModel()
        mockPhotoLibrary.mockAuthorizationStatus = .authorized

        // When
        try await viewModel.saveToPhotoLibrary()

        // Then
        #expect(viewModel.isSaving == false)
    }

    // MARK: - SNS共有のテスト

    @Test("SNS共有が成功した場合、trueを返す")
    func SNS共有が成功した場合trueを返す() async throws {
        // Given
        let (viewModel, _, mockActivityController) = createViewModel()
        mockActivityController.shouldSucceed = true

        // When
        let result = try await viewModel.shareToSNS()

        // Then
        #expect(result == true)
        #expect(mockActivityController.shareCallCount == 1)
    }

    @Test("SNS共有がキャンセルされた場合、falseを返す")
    func SNS共有がキャンセルされた場合falseを返す() async throws {
        // Given
        let (viewModel, _, mockActivityController) = createViewModel()
        mockActivityController.shouldSucceed = false

        // When
        let result = try await viewModel.shareToSNS()

        // Then
        #expect(result == false)
        #expect(mockActivityController.shareCallCount == 1)
    }

    @Test("サムネイル付きで共有した場合、両方のアイテムが渡される")
    func サムネイル付きで共有した場合両方のアイテムが渡される() async throws {
        // Given
        let thumbnail = createMockThumbnail()
        let (viewModel, _, mockActivityController) = createViewModel(thumbnailImage: thumbnail)
        mockActivityController.shouldSucceed = true

        // When
        _ = try await viewModel.shareToSNS()

        // Then
        #expect(mockActivityController.lastSharedItems.count == 2)

        // 1つ目はURL
        let sharedURL = mockActivityController.lastSharedItems[0] as? URL
        #expect(sharedURL == viewModel.exportedVideoURL)

        // 2つ目はUIImage
        let sharedImage = mockActivityController.lastSharedItems[1] as? UIImage
        #expect(sharedImage != nil)
    }

    @Test("動画URLのみで共有した場合、1つのアイテムが渡される")
    func 動画URLのみで共有した場合1つのアイテムが渡される() async throws {
        // Given: サムネイルなし
        let (viewModel, _, mockActivityController) = createViewModel(thumbnailImage: nil)
        mockActivityController.shouldSucceed = true

        // When
        _ = try await viewModel.shareToSNS()

        // Then
        #expect(mockActivityController.lastSharedItems.count == 1)

        // URLのみ
        let sharedURL = mockActivityController.lastSharedItems[0] as? URL
        #expect(sharedURL == viewModel.exportedVideoURL)
    }
}
