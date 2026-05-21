import SwiftUI

struct MyRatingsView: View {
    @EnvironmentObject private var session: SessionManager
    @StateObject var viewModel: MyRatingsViewModel
    let restaurantService: RestaurantService
    let reviewService: ReviewService
    let disableAutoLoad: Bool

    init(
        viewModel: MyRatingsViewModel,
        restaurantService: RestaurantService,
        reviewService: ReviewService,
        disableAutoLoad: Bool = false
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.restaurantService = restaurantService
        self.reviewService = reviewService
        self.disableAutoLoad = disableAutoLoad
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Caricamento voti...")
                } else if let error = viewModel.errorMessage {
                    UnavailableStateView(title: "Errore", systemImage: "exclamationmark.triangle", message: error)
                } else if viewModel.items.isEmpty {
                    UnavailableStateView(title: "Nessun voto", systemImage: "chart.bar", message: "Non hai ancora lasciato recensioni")
                } else {
                    List(Array(viewModel.items.enumerated()), id: \.element.restaurantId) { index, item in
                        NavigationLink {
                            RestaurantDetailView(
                                viewModel: RestaurantDetailViewModel(
                                    restaurantId: item.restaurantId,
                                    restaurantService: restaurantService,
                                    reviewService: reviewService,
                                    currentUserId: session.currentUser?.id
                                )
                            )
                        } label: {
                            HStack(spacing: 12) {
                                Text("\(index + 1)")
                                    .font(index < 3 ? .headline : .subheadline.weight(.bold))
                                    .foregroundStyle(index < 3 ? .white : .secondary)
                                    .frame(width: 34, height: 34)
                                    .background(positionColor(for: index), in: Circle())

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.restaurantName)
                                        .font(.headline)
                                        .lineLimit(1)

                                    Text("Voto medio: \(item.averageRating, specifier: "%.2f")")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("I tuoi voti")
            .task {
                guard !disableAutoLoad else { return }
                await viewModel.load(userId: session.currentUser?.id)
            }
            .refreshable {
                guard !disableAutoLoad else { return }
                await viewModel.load(userId: session.currentUser?.id)
            }
        }
    }

    private func positionColor(for index: Int) -> Color {
        switch index {
        case 0: return Color(red: 0.93, green: 0.76, blue: 0.26) // gold
        case 1: return Color(red: 0.67, green: 0.70, blue: 0.75) // silver
        case 2: return Color(red: 0.74, green: 0.48, blue: 0.29) // bronze
        default: return Color(.secondarySystemBackground)
        }
    }
}

#if DEBUG
struct MyRatingsView_Previews: PreviewProvider {
    static var previews: some View {
        let client = APIClient(baseURL: URL(string: "https://example.com/api")!)
        let viewModel = MyRatingsViewModel(service: RankingService(client: client))
        viewModel.items = [
            UserRankingItem(
                restaurantId: "r1",
                restaurantName: "Trattoria del Porto",
                cuisine: "Ristorante",
                address: "Centro",
                averageRating: 9.25,
                serviceRating: 9,
                priceRating: 9.5,
                menuRating: 9.25,
                comment: "Ottimo",
                createdAt: nil,
                reviewCount: 42
            ),
            UserRankingItem(
                restaurantId: "r2",
                restaurantName: "Pizzeria Vesuvio",
                cuisine: "Pizzeria",
                address: "Nord",
                averageRating: 8.75,
                serviceRating: 8.5,
                priceRating: 9,
                menuRating: 8.75,
                comment: "Molto buona",
                createdAt: nil,
                reviewCount: 31
            ),
            UserRankingItem(
                restaurantId: "r3",
                restaurantName: "Sushi Hana",
                cuisine: "Sushi",
                address: "Sud",
                averageRating: 8.5,
                serviceRating: 8.5,
                priceRating: 8.5,
                menuRating: 8.5,
                comment: "Consigliato",
                createdAt: nil,
                reviewCount: 19
            ),
            UserRankingItem(
                restaurantId: "r4",
                restaurantName: "Bar Centrale",
                cuisine: "Bar",
                address: "Piazza",
                averageRating: 7.9,
                serviceRating: 8,
                priceRating: 7.5,
                menuRating: 8.25,
                comment: "Ok",
                createdAt: nil,
                reviewCount: 11
            )
        ]

        let session = SessionManager()
        session.currentUser = User(id: "u1", username: "preview", displayName: "Preview", email: "", role: "user")
        session.isAuthenticated = true

        return MyRatingsView(
            viewModel: viewModel,
            restaurantService: RestaurantService(client: client),
            reviewService: ReviewService(client: client),
            disableAutoLoad: true
        )
        .environmentObject(session)
    }
}
#endif
