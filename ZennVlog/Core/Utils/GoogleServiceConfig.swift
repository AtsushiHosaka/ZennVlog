import Foundation

struct GoogleServiceConfig: Sendable {
    let projectID: String
    let apiKey: String
    let storageBucket: String
}

enum GoogleServiceConfigLoader {
    static func load() -> GoogleServiceConfig {
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: Any] else {
            fatalError("GoogleService-Info.plist not found. Add your Firebase config file to the app target.")
        }

        guard let projectID = dict["PROJECT_ID"] as? String, !projectID.isEmpty else {
            fatalError("PROJECT_ID not configured in GoogleService-Info.plist")
        }

        guard let apiKey = dict["API_KEY"] as? String, !apiKey.isEmpty else {
            fatalError("API_KEY not configured in GoogleService-Info.plist")
        }

        guard let storageBucket = dict["STORAGE_BUCKET"] as? String, !storageBucket.isEmpty else {
            fatalError("STORAGE_BUCKET not configured in GoogleService-Info.plist")
        }

        return GoogleServiceConfig(
            projectID: projectID,
            apiKey: apiKey,
            storageBucket: storageBucket
        )
    }
}
