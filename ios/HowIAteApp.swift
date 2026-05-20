import SwiftUI

@main
struct HowIAteApp: App {
    @StateObject private var session = SessionManager()
    private let client = APIClient(baseURL: AppConfig.apiBaseURL)
    private let tokenProvider = AuthTokenProvider()

    var body: some Scene {
        WindowGroup {
            AppRootView(client: client)
                .environmentObject(session)
                .task {
                    client.setTokenProvider(tokenProvider)
                    session.restoreSession()
                }
        }
    }
}
