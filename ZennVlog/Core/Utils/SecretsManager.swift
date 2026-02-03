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

    static var imagenAPIKey: String {
        guard let key = secrets["IMAGEN_API_KEY"] as? String, !key.isEmpty else {
            fatalError("IMAGEN_API_KEY not configured in Secrets.plist")
        }
        return key
    }
}
