import SwiftUI

struct RestaurantsView: View {
    @EnvironmentObject private var session: SessionManager
    @StateObject var viewModel: RestaurantsViewModel

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Caricamento...")
                } else if let error = viewModel.errorMessage {
                    UnavailableStateView(title: "Errore", systemImage: "exclamationmark.triangle", message: error)
                } else {
                    List(viewModel.restaurants) { restaurant in
                        NavigationLink {
                            RestaurantDetailView(
                                viewModel: RestaurantDetailViewModel(
                                    restaurantId: restaurant.id,
                                    restaurantService: viewModel.restaurantService,
                                    reviewService: viewModel.reviewService,
                                    currentUserId: session.currentUser?.id
                                )
                            )
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(restaurant.name)
                                    .font(.headline)
                                if let cuisine = restaurant.cuisine, !cuisine.isEmpty {
                                    Text(cuisine)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                if let address = restaurant.address, !address.isEmpty {
                                    Text(address)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Ristoranti")
            .task { await viewModel.load() }
            .refreshable { await viewModel.load() }
        }
    }
}
