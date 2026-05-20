import SwiftUI

struct AppRootView: View {
    @EnvironmentObject private var session: SessionManager
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    var body: some View {
        Group {
            if session.isAuthenticated {
                MainTabView(client: client)
            } else {
                LoginView(viewModel: LoginViewModel(authService: AuthService(client: client, session: session)))
            }
        }
    }
}

private struct MainTabView: View {
    @EnvironmentObject private var session: SessionManager
    let client: APIClient

    private var authService: AuthService {
        AuthService(client: client, session: session)
    }

    private var canManageSuggestions: Bool {
        guard let role = session.currentUser?.role else { return false }
        return role == "admin" || role == "superadmin"
    }

    var body: some View {
        TabView {
            RestaurantsView(
                viewModel: RestaurantsViewModel(
                    restaurantService: RestaurantService(client: client),
                    reviewService: ReviewService(client: client),
                    rankingService: RankingService(client: client),
                    suggestionService: SuggestionService(client: client)
                )
            )
            .tabItem {
                Label("Ristoranti", systemImage: "fork.knife")
            }

            RankingsView(
                viewModel: RankingsViewModel(service: RankingService(client: client))
            )
            .tabItem {
                Label("Rankings", systemImage: "chart.bar.fill")
            }

            if canManageSuggestions {
                AdminPanelView(client: client)
                .tabItem {
                    Label("Admin", systemImage: "person.3.fill")
                }
            }

            SettingsView(
                authService: authService
            )
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
        }
        .task {
            if session.currentUser == nil {
                _ = try? await authService.fetchMe()
            }
        }
    }
}
