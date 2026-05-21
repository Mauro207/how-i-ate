import SwiftUI

struct RestaurantsView: View {
    @EnvironmentObject private var session: SessionManager
    @StateObject var viewModel: RestaurantsViewModel
    let disableAutoLoad: Bool

    init(viewModel: RestaurantsViewModel, disableAutoLoad: Bool = false) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.disableAutoLoad = disableAutoLoad
    }

    private var displayName: String {
        session.currentUser?.displayName ?? session.currentUser?.username ?? "Utente"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16, pinnedViews: []) {
                    if viewModel.isLoading {
                        ProgressView("Caricamento homepage...")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 24)
                    } else if let error = viewModel.errorMessage, viewModel.recentRestaurants.isEmpty {
                        UnavailableStateView(title: "Errore", systemImage: "exclamationmark.triangle", message: error)
                            .frame(height: 220)
                    } else {
                        if viewModel.recentRestaurants.isEmpty {
                            UnavailableStateView(title: "Nessun luogo trovato", systemImage: "fork.knife.circle", message: "Aggiungi o suggerisci il primo ristorante")
                                .frame(height: 220)
                        }

                        if let rankingError = viewModel.rankingErrorMessage, viewModel.topRankings.isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: "chart.bar.xaxis")
                                Text("Classifica non disponibile: \(rankingError)")
                                    .font(.caption)
                                    .lineLimit(2)
                            }
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 4)
                        }

                        if !viewModel.topRankings.isEmpty {
                            HomeSectionTitle(title: "Top ranking", subtitle: "I migliori luoghi del momento")

                            VStack(spacing: 10) {
                                ForEach(Array(viewModel.topRankings.enumerated()), id: \.element.restaurantId) { index, item in
                                    NavigationLink {
                                        RestaurantDetailView(
                                            viewModel: RestaurantDetailViewModel(
                                                restaurantId: item.restaurantId,
                                                restaurantService: viewModel.restaurantService,
                                                reviewService: viewModel.reviewService,
                                                currentUserId: session.currentUser?.id
                                            )
                                        )
                                    } label: {
                                        HStack(spacing: 12) {
                                            Text("\(index + 1)")
                                                .font(index < 3 ? .headline : .subheadline.weight(.bold))
                                                .foregroundStyle(index < 3 ? .white : .secondary)
                                                .frame(width: 34, height: 34)
                                                .background(rankBadgeColor(for: index), in: Circle())

                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(item.restaurantName)
                                                    .font(.subheadline.weight(.semibold))
                                                    .lineLimit(1)
                                                Text("Media \(item.averageRating, specifier: "%.2f") · \(item.reviewCount) review")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }

                                            Spacer(minLength: 0)
                                        }
                                        .padding(12)
                                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    }
                                    .buttonStyle(.plain)
                                }

                                NavigationLink {
                                    RankingsView(
                                        viewModel: RankingsViewModel(service: viewModel.rankingService),
                                        restaurantService: viewModel.restaurantService,
                                        reviewService: viewModel.reviewService
                                    )
                                } label: {
                                    Text("Vai alla classifica completa")
                                        .font(.subheadline.weight(.semibold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Color.indigo.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if !viewModel.recentRestaurants.isEmpty {
                            HomeSectionTitle(title: "Ultimi luoghi", subtitle: "Recensisci i luoghi creati di recente")

                            VStack(spacing: 10) {
                                ForEach(viewModel.recentRestaurants) { restaurant in
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
                                        RestaurantRowCard(restaurant: restaurant)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 24)
            }
            .background(
                LinearGradient(
                    colors: [Color.indigo.opacity(0.12), Color(.systemBackground), Color(.systemBackground)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .navigationTitle("Ciao \(displayName)")
            .refreshable {
                guard !disableAutoLoad else { return }
                await viewModel.load()
            }
            .task {
                guard !disableAutoLoad else { return }
                await viewModel.load()
            }
        }
    }
}

private struct HomeSectionTitle: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 6)
    }
}

private struct RestaurantRowCard: View {
    let restaurant: Restaurant

    private var cuisineIconName: String {
        let normalized = (restaurant.cuisine ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.contains("gelateria") { return "snowflake" }
        if normalized.contains("pizzeria") { return "flame" }
        if normalized.contains("paninoteca") { return "takeoutbag.and.cup.and.straw" }
        if normalized.contains("sushi") { return "fish" }
        if normalized.contains("pub") || normalized.contains("bar") || normalized.contains("enoteca") { return "wineglass" }
        if normalized.contains("pasticceria") { return "birthday.cake" }
        if normalized.contains("braceria") { return "flame.circle" }
        return "fork.knife"
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.indigo.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: cuisineIconName)
                    .foregroundStyle(Color.indigo)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(restaurant.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                if let address = restaurant.address, !address.isEmpty {
                    Text(address)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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

