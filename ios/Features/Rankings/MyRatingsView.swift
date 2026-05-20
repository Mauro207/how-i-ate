import SwiftUI

struct MyRatingsView: View {
    @EnvironmentObject private var session: SessionManager
    @StateObject var viewModel: MyRatingsViewModel
    let restaurantService: RestaurantService
    let reviewService: ReviewService

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
                    List(viewModel.items, id: \.restaurantId) { item in
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
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.restaurantName)
                                    .font(.headline)
                                Text("Media personale: \(item.averageRating, specifier: "%.2f")")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text(item.comment)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("I tuoi voti")
            .task { await viewModel.load(userId: session.currentUser?.id) }
            .refreshable { await viewModel.load(userId: session.currentUser?.id) }
        }
    }
}
