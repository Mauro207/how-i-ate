import SwiftUI

struct AppRootView: View {
    @EnvironmentObject private var session: SessionManager
    private let client: APIClient
    private let tokenProvider = AuthTokenProvider()

    private var isRunningInPreviews: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    private var isLivePreviewEnabled: Bool {
        ProcessInfo.processInfo.environment["HOWIATE_PREVIEW_LIVE_DATA"] != "0"
    }

    private var shouldDisablePreviewNetworking: Bool {
        isRunningInPreviews && !isLivePreviewEnabled
    }

    init(client: APIClient) {
        self.client = client
    }

    var body: some View {
        Group {
            if session.isAuthenticated {
                MainTabView(client: client)
            } else {
                LoginView(
                    viewModel: LoginViewModel(
                        authService: AuthService(client: client, session: session),
                        previewMode: shouldDisablePreviewNetworking
                    )
                )
            }
        }
        .task {
            client.setTokenProvider(tokenProvider)
            session.restoreSession()
        }
    }
}

private struct MainTabView: View {
    @EnvironmentObject private var session: SessionManager
    let client: APIClient
    private let restaurantService: RestaurantService
    private let reviewService: ReviewService
    private let rankingService: RankingService
    private let suggestionService: SuggestionService

    init(client: APIClient) {
        self.client = client
        let sharedRankingService = RankingService(client: client)
        let sharedRestaurantService = RestaurantService(client: client, rankingService: sharedRankingService)
        rankingService = sharedRankingService
        restaurantService = sharedRestaurantService
        reviewService = ReviewService(client: client, rankingService: sharedRankingService)
        suggestionService = SuggestionService(client: client) {
            sharedRestaurantService.invalidateRestaurantCaches()
        }
    }

    private var isRunningInPreviews: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    private var isLivePreviewEnabled: Bool {
        ProcessInfo.processInfo.environment["HOWIATE_PREVIEW_LIVE_DATA"] != "0"
    }

    private var shouldDisablePreviewNetworking: Bool {
        isRunningInPreviews && !isLivePreviewEnabled
    }

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
                    restaurantService: restaurantService,
                    reviewService: reviewService,
                    rankingService: rankingService,
                    suggestionService: suggestionService
                ),
                disableAutoLoad: shouldDisablePreviewNetworking
            )
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }

            SearchView(
                viewModel: SearchViewModel(
                    restaurantService: restaurantService,
                    authService: AuthService(client: client, session: session)
                ),
                restaurantService: restaurantService,
                reviewService: reviewService,
                rankingService: rankingService
            )
            .tabItem {
                Label("Cerca", systemImage: "magnifyingglass")
            }

            MyRatingsView(
                viewModel: MyRatingsViewModel(service: rankingService),
                restaurantService: restaurantService,
                reviewService: reviewService,
                disableAutoLoad: shouldDisablePreviewNetworking
            )
            .tabItem {
                Label("I tuoi voti", systemImage: "chart.bar.fill")
            }

            if isAdminOrSuperAdmin {
                AdminAddPlaceView(
                    restaurantService: restaurantService,
                    reviewService: reviewService,
                    suggestionService: suggestionService,
                    disableInitialLoad: shouldDisablePreviewNetworking
                )
                .tabItem {
                    Label("Aggiungi", systemImage: "plus.circle.fill")
                }
            } else {
                AddSuggestionTabView(
                    service: suggestionService,
                    restaurantService: restaurantService,
                    reviewService: reviewService
                )
                    .tabItem {
                        Label("Suggerisci", systemImage: "plus.circle.fill")
                    }
            }

            SettingsView(
                authService: authService,
                suggestionService: suggestionService,
                disableAutoLoad: shouldDisablePreviewNetworking
            )
            .tabItem {
                Label("Impostazioni", systemImage: "gearshape.fill")
            }
        }
        .task {
            guard !shouldDisablePreviewNetworking else { return }
            if session.currentUser == nil {
                _ = try? await authService.fetchMe()
            }
        }
    }
}
