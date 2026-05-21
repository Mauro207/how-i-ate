import SwiftUI

struct RankingsView: View {
    @EnvironmentObject private var session: SessionManager
    @StateObject var viewModel: RankingsViewModel
    let restaurantService: RestaurantService
    let reviewService: ReviewService

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Caricamento rankings...")
                } else if let error = viewModel.errorMessage {
                    UnavailableStateView(title: "Errore", systemImage: "exclamationmark.triangle", message: error)
                } else {
                    List(Array(viewModel.rankings.enumerated()), id: \.element.restaurantId) { index, item in
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
                            HStack(alignment: .top) {
                                Text("\(index + 1)")
                                    .font(index < 3 ? .headline : .subheadline.weight(.bold))
                                    .foregroundStyle(index < 3 ? .white : .secondary)
                                    .frame(width: 34, height: 34)
                                    .background(rankBadgeColor(for: index), in: Circle())

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.restaurantName)
                                        .font(.headline)
                                    Text("Media: \(item.averageRating, specifier: "%.2f") · Review: \(item.reviewCount)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Rankings")
            .task { await viewModel.loadGlobal() }
            .refreshable { await viewModel.loadGlobal() }
        }
    }

    private func rankBadgeColor(for index: Int) -> Color {
        switch index {
        case 0: return Color(red: 0.93, green: 0.76, blue: 0.26)
        case 1: return Color(red: 0.67, green: 0.70, blue: 0.75)
        case 2: return Color(red: 0.74, green: 0.48, blue: 0.29)
        default: return Color(.secondarySystemBackground)
        }
    }
}
