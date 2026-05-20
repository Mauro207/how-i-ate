import Foundation

enum AppConfig {
    // Default: backend produzione (allineato al frontend Angular).
    // Override opzionale da Xcode Scheme: API_BASE_URL=http://localhost:3000/api
    private static let defaultAPIBaseURL = "https://how-i-ate-backend.vercel.app/api"

    static let apiBaseURL: URL = {
        let override = ProcessInfo.processInfo.environment["API_BASE_URL"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let override, !override.isEmpty, let url = URL(string: override) {
            return url
        }
        return URL(string: defaultAPIBaseURL)!
    }()
}
