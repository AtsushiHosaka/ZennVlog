import Foundation

actor FirestoreTemplateRepository: TemplateRepositoryProtocol {

    // MARK: - Properties

    private let dataSource: any FirestoreRESTDataSourceProtocol

    // MARK: - Init

    init(dataSource: any FirestoreRESTDataSourceProtocol) {
        self.dataSource = dataSource
    }

    // MARK: - TemplateRepositoryProtocol

    func fetchAll() async throws -> [TemplateDTO] {
        do {
            let documents = try await dataSource.fetchCollection(named: "templates")
            return try documents
                .map(decodeTemplate)
                .sorted { $0.id < $1.id }
        } catch let error as TemplateRepositoryError {
            throw error
        } catch {
            throw TemplateRepositoryError.fetchFailed(underlying: error)
        }
    }

    func fetch(by id: String) async throws -> TemplateDTO? {
        do {
            guard let document = try await dataSource.fetchDocument(collection: "templates", id: id) else {
                return nil
            }
            return try decodeTemplate(document)
        } catch let error as TemplateRepositoryError {
            throw error
        } catch {
            throw TemplateRepositoryError.fetchFailed(underlying: error)
        }
    }

    // MARK: - Private Methods

    private func decodeTemplate(_ document: FirestoreDocument) throws -> TemplateDTO {
        do {
            let fields = document.fields
            let name = try requireString(fields["name"], fieldName: "name")
            let description = try requireString(fields["description"], fieldName: "description")
            let referenceVideoURL = try requireString(fields["referenceVideoUrl"], fieldName: "referenceVideoUrl")
            let explanation = try requireString(fields["explanation"], fieldName: "explanation")
            let segments = try decodeSegments(fields["segments"])

            return TemplateDTO(
                id: document.documentID,
                name: name,
                description: description,
                referenceVideoUrl: referenceVideoURL,
                explanation: explanation,
                segments: segments.sorted { $0.order < $1.order }
            )
        } catch let error as TemplateRepositoryError {
            throw error
        } catch {
            throw TemplateRepositoryError.decodeFailed(underlying: error)
        }
    }

    private func decodeSegments(_ value: FirestoreValue?) throws -> [SegmentDTO] {
        guard let values = value?.array else {
            throw TemplateRepositoryError.decodeFailed(
                underlying: NSError(domain: "FirestoreTemplateRepository", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "segments is missing or invalid"
                ])
            )
        }

        return try values.enumerated().map { index, firestoreValue in
            guard let map = firestoreValue.map else {
                throw TemplateRepositoryError.decodeFailed(
                    underlying: NSError(domain: "FirestoreTemplateRepository", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "segments[\(index)] is not a map"
                    ])
                )
            }

            guard let order = map["order"]?.int,
                  let startSec = map["startSec"]?.double,
                  let endSec = map["endSec"]?.double,
                  let description = map["description"]?.string else {
                throw TemplateRepositoryError.decodeFailed(
                    underlying: NSError(domain: "FirestoreTemplateRepository", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "segments[\(index)] has invalid fields"
                    ])
                )
            }

            return SegmentDTO(
                order: order,
                startSec: startSec,
                endSec: endSec,
                description: description
            )
        }
    }

    private func requireString(_ value: FirestoreValue?, fieldName: String) throws -> String {
        guard let string = value?.string, !string.isEmpty else {
            throw TemplateRepositoryError.decodeFailed(
                underlying: NSError(domain: "FirestoreTemplateRepository", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "\(fieldName) is missing"
                ])
            )
        }

        return string
    }
}
