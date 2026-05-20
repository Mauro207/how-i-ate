import SwiftUI

struct RankingsView: View {
    @StateObject var viewModel: RankingsViewModel

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Caricamento rankings...")
                } else if let error = viewModel.errorMessage {
                    UnavailableStateView(title: "Errore", systemImage: "exclamationmark.triangle", message: error)
                } else {
                    List(Array(viewModel.rankings.enumerated()), id: \.element.restaurantId) { index, item in
                        HStack(alignment: .top) {
                            Text("#\(index + 1)")
                                .font(.headline)
                                .frame(width: 44, alignment: .leading)

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
            .navigationTitle("Rankings")
            .task { await viewModel.loadGlobal() }
            .refreshable { await viewModel.loadGlobal() }
        }
    }
}
