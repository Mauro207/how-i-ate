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
                            MyRatingRowView(index: index, item: item)
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
}
