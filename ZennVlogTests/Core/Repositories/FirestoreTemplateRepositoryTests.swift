import Foundation
import Testing
@testable import ZennVlog

private actor TemplateDataSourceStub: FirestoreRESTDataSourceProtocol {
    var documents: [FirestoreDocument] = []
    var documentByID: [String: FirestoreDocument] = [:]

    func setDocuments(_ value: [FirestoreDocument]) {
        documents = value
    }

    func setDocument(id: String, document: FirestoreDocument) {
        documentByID[id] = document
    }

    func fetchCollection(named collection: String) async throws -> [FirestoreDocument] {
        documents
    }

    func fetchDocument(collection: String, id: String) async throws -> FirestoreDocument? {
        documentByID[id]
    }
}

@Suite("FirestoreTemplateRepository Tests")
struct FirestoreTemplateRepositoryTests {

    @Test("decode template successfully")
    func decodeTemplateSuccessfully() async throws {
        let stub = TemplateDataSourceStub()
        await stub.setDocuments([
            FirestoreDocument(
                name: "projects/demo/databases/(default)/documents/templates/daily-vlog",
                fields: [
                    "name": .string("1日のVlog"),
                    "description": .string("desc"),
                    "referenceVideoUrl": .string("https://example.com"),
                    "explanation": .string("exp"),
                    "segments": .array([
                        .map([
                            "order": .integer(1),
                            "startSec": .double(5),
                            "endSec": .double(10),
                            "description": .string("second")
                        ]),
                        .map([
                            "order": .integer(0),
                            "startSec": .double(0),
                            "endSec": .double(5),
                            "description": .string("first")
                        ])
                    ])
                ]
            )
        ])

        let repository = FirestoreTemplateRepository(dataSource: stub)
        let templates = try await repository.fetchAll()

        #expect(templates.count == 1)
        #expect(templates[0].id == "daily-vlog")
        #expect(templates[0].segments[0].order == 0)
        #expect(templates[0].segments[1].order == 1)
    }

    @Test("missing field throws decodeFailed")
    func missingFieldThrowsDecodeFailed() async throws {
        let stub = TemplateDataSourceStub()
        await stub.setDocuments([
            FirestoreDocument(
                name: "projects/demo/databases/(default)/documents/templates/broken",
                fields: [
                    "name": .string("broken")
                ]
            )
        ])

        let repository = FirestoreTemplateRepository(dataSource: stub)

        do {
            _ = try await repository.fetchAll()
            #expect(Bool(false), "decodeFailed should be thrown")
        } catch let error as TemplateRepositoryError {
            switch error {
            case .fetchFailed(let underlying):
                #expect((underlying as? TemplateRepositoryError) != nil)
            case .decodeFailed:
                #expect(Bool(true))
            default:
                #expect(Bool(false), "unexpected error type")
            }
        }
    }
}
