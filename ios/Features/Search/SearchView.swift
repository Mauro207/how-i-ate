import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var session: SessionManager
    @StateObject var viewModel: SearchViewModel
    let restaurantService: RestaurantService
    let reviewService: ReviewService

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Ricerca in corso...")
                } else if let error = viewModel.errorMessage {
                    UnavailableStateView(title: "Errore", systemImage: "exclamationmark.triangle", message: error)
                } else if viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    UnavailableStateView(title: "Cerca un luogo", systemImage: "magnifyingglass", message: "Inserisci nome, cucina o indirizzo")
                } else if viewModel.results.isEmpty {
                    UnavailableStateView(title: "Nessun risultato", systemImage: "fork.knife.circle", message: "Prova con un termine diverso")
                } else {
                    List(viewModel.results) { restaurant in
                        NavigationLink {
                            RestaurantDetailView(
                                viewModel: RestaurantDetailViewModel(
                                    restaurantId: restaurant.id,
                                    restaurantService: restaurantService,
                                    reviewService: reviewService,
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
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Cerca")
            .searchable(text: $viewModel.query, prompt: "Nome, cucina o indirizzo")
            .onSubmit(of: .search) {
                Task { await viewModel.search() }
            }
            .onChange(of: viewModel.query) { newValue in
                if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    viewModel.results = []
                    viewModel.errorMessage = nil
                }
            }
        }
    }
}
