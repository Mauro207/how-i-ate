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
                LazyVStack(spacing: 18, pinnedViews: []) {
                    if viewModel.isLoading {
                        loadingCard
                    } else if let error = viewModel.errorMessage, viewModel.recentRestaurants.isEmpty {
                        UnavailableStateView(title: "Errore", systemImage: "exclamationmark.triangle", message: error)
                            .frame(height: 220)
                            .frame(maxWidth: .infinity)
                            .homeGlassCard()
                    } else {
                        if viewModel.recentRestaurants.isEmpty {
                            UnavailableStateView(title: "Nessun luogo trovato", systemImage: "fork.knife.circle", message: "Aggiungi o suggerisci il primo ristorante")
                                .frame(height: 220)
                                .frame(maxWidth: .infinity)
                                .homeGlassCard()
                        }

                        if let rankingError = viewModel.rankingErrorMessage, viewModel.topRankings.isEmpty {
                            rankingErrorBanner(rankingError)
                        }

                        if !viewModel.topRankings.isEmpty {
                            HomeSectionTitle(title: "Top ranking", subtitle: "I migliori luoghi del momento")

                            VStack(spacing: 10) {
                                ForEach(Array(viewModel.topRankings.enumerated()), id: \.offset) { index, item in
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
                                        TopRankingRow(item: item, index: index)
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
                                    Label("Vai alla classifica completa", systemImage: "chart.bar.xaxis")
                                        .font(.subheadline.weight(.semibold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .foregroundStyle(Color.indigo)
                                        .background(Color.indigo.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                            .homeGlassCard()
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
                            .homeGlassCard()
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .background(homeBackground)
            .navigationTitle("Ciao \(displayName)")
            .refreshable {
                guard !disableAutoLoad else { return }
                await viewModel.load(forceRefresh: true)
            }
            .task {
                guard !disableAutoLoad else { return }
                await viewModel.load()
            }
        }
    }

    private var homeBackground: some View {
        LinearGradient(
            colors: [
                Color(uiColor: .systemGroupedBackground),
                Color.indigo.opacity(0.12),
                Color(uiColor: .systemBackground)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var loadingCard: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Caricamento homepage...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .homeGlassCard()
    }

    private func rankingErrorBanner(_ error: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "chart.bar.xaxis")
                .font(.footnote.weight(.semibold))
            Text("Classifica non disponibile: \(error)")
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct HomeSectionTitle: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.title3.weight(.bold))
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 6)
    }
}

private struct TopRankingRow: View {
    let item: RankingItem
    let index: Int

    var body: some View {
        HStack(spacing: 12) {
            Text("\(index + 1)")
                .font(index < 3 ? .headline : .subheadline.weight(.bold))
                .foregroundStyle(index < 3 ? .white : .secondary)
                .frame(width: 36, height: 36)
                .background(rankBadgeColor(for: index), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(item.restaurantName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text("Valutazione media: \(String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), item.averageRating)) · \(item.reviewCount) recensioni")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.72), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        }
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
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.indigo.opacity(0.14))
                    .frame(width: 46, height: 46)
                Image(systemName: cuisineIconName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.indigo)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(restaurant.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
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
        .background(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.72), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        }
    }
}

private struct HomeGlassCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .padding(12)
                .glassEffect(.regular.tint(.indigo.opacity(0.06)), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        } else {
            content
                .padding(12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.primary.opacity(0.07), lineWidth: 1)
                }
        }
    }
}

private extension View {
    func homeGlassCard() -> some View {
        modifier(HomeGlassCardModifier())
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
