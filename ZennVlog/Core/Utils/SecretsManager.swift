import Foundation

enum SecretsManager {
    private static var secrets: [String: Any] = {
        guard let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: Any] else {
            fatalError("Secrets.plist not found. Copy Secrets.plist.example to Secrets.plist and fill in your API keys.")
        }
        return dict
    }()

    static var geminiAPIKey: String {
        guard let key = secrets["GEMINI_API_KEY"] as? String, !key.isEmpty else {
            fatalError("GEMINI_API_KEY not configured in Secrets.plist")
        }
        return key
    }

    static var geminiTextModel: String {
        guard let model = secrets["GEMINI_TEXT_MODEL"] as? String, !model.isEmpty else {
            fatalError("GEMINI_TEXT_MODEL not configured in Secrets.plist")
        }
        return model
    }

    static var geminiVideoModel: String {
        guard let model = secrets["GEMINI_VIDEO_MODEL"] as? String, !model.isEmpty else {
            fatalError("GEMINI_VIDEO_MODEL not configured in Secrets.plist")
        }
        return model
    }

    static var geminiImageModel: String {
        guard let model = secrets["GEMINI_IMAGE_MODEL"] as? String, !model.isEmpty else {
            fatalError("GEMINI_IMAGE_MODEL not configured in Secrets.plist")
        }
        return model
    }
}
