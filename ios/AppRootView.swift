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

    private var isAdminOrSuperAdmin: Bool {
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
                Label("Home", systemImage: "house.fill")
            }

            SearchView(
                viewModel: SearchViewModel(
                    restaurantService: RestaurantService(client: client)
                ),
                restaurantService: RestaurantService(client: client),
                reviewService: ReviewService(client: client)
            )
            .tabItem {
                Label("Cerca", systemImage: "magnifyingglass")
            }

            MyRatingsView(
                viewModel: MyRatingsViewModel(service: RankingService(client: client)),
                restaurantService: RestaurantService(client: client),
                reviewService: ReviewService(client: client)
            )
            .tabItem {
                Label("I tuoi voti", systemImage: "chart.bar.fill")
            }

            if isAdminOrSuperAdmin {
                AdminAddPlaceView(
                    restaurantService: RestaurantService(client: client),
                    suggestionService: SuggestionService(client: client)
                )
                .tabItem {
                    Label("Aggiungi", systemImage: "plus.circle.fill")
                }
            } else {
                AddSuggestionTabView(
                    service: SuggestionService(client: client),
                    restaurantService: RestaurantService(client: client)
                )
                    .tabItem {
                        Label("Suggerisci", systemImage: "plus.circle.fill")
                    }
            }

            SettingsView(
                authService: authService
            )
            .tabItem {
                Label("Impostazioni", systemImage: "gearshape.fill")
            }
        }
        .task {
            if session.currentUser == nil {
                _ = try? await authService.fetchMe()
            }
        }
    }
}

#if DEBUG
struct AppRootView_Previews: PreviewProvider {
    static var previews: some View {
        let session = SessionManager()
        let client = APIClient(baseURL: URL(string: "https://example.com/api")!)

        return AppRootView(client: client)
            .environmentObject(session)
    }
}
#endif
