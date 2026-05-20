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
            .task { await viewModel.load(userId: session.currentUser?.id) }
            .refreshable { await viewModel.load(userId: session.currentUser?.id) }
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
