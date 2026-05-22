import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var session: SessionManager
    @StateObject var viewModel: SearchViewModel
    let restaurantService: RestaurantService
    let reviewService: ReviewService
    let rankingService: RankingService

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    content
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .background(searchBackground)
            .navigationTitle("Cerca")
            .searchable(text: $viewModel.query, prompt: "Nome luogo, cucina, indirizzo o utente")
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

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            loadingCard
        } else if let error = viewModel.errorMessage {
            stateCard(title: "Errore", systemImage: "exclamationmark.triangle", message: error)
        } else if viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            stateCard(title: "Cerca", systemImage: "magnifyingglass", message: "Inserisci luogo o utente")
        } else if viewModel.results.isEmpty {
            stateCard(title: "Nessun risultato", systemImage: "fork.knife.circle", message: "Prova con un termine diverso")
        } else {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Risultati")
                        .font(.title3.weight(.bold))
                    Text("\(viewModel.results.count) risultati trovati")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 10) {
                    ForEach(viewModel.results) { item in
                        NavigationLink {
                            destinationView(for: item)
                        } label: {
                            SearchResultCard(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .searchGlassCard()
        }
    }

    private var searchBackground: some View {
        LinearGradient(
            colors: [
                Color(uiColor: .systemGroupedBackground),
                Color.indigo.opacity(0.10),
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
            Text("Ricerca in corso...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .searchGlassCard()
    }

    private func stateCard(title: String, systemImage: String, message: String) -> some View {
        UnavailableStateView(title: title, systemImage: systemImage, message: message)
            .frame(height: 240)
            .frame(maxWidth: .infinity)
            .searchGlassCard()
    }

    @ViewBuilder
    private func destinationView(for item: SearchViewModel.SearchResultItem) -> some View {
        switch item {
        case let .restaurant(restaurant):
            RestaurantDetailView(
                viewModel: RestaurantDetailViewModel(
                    restaurantId: restaurant.id,
                    restaurantService: restaurantService,
                    reviewService: reviewService,
                    currentUserId: session.currentUser?.id
                )
            )
        case let .user(user):
            MyRatingsView(
                viewModel: MyRatingsViewModel(service: rankingService),
                restaurantService: restaurantService,
                reviewService: reviewService,
                targetUserId: user.id,
                targetUserDisplayName: user.displayName?.nilIfEmpty ?? user.username,
                embedInNavigationStack: false
            )
        }
    }
}

private struct SearchResultCard: View {
    let item: SearchViewModel.SearchResultItem

    private var title: String {
        switch item {
        case let .restaurant(restaurant):
            return restaurant.name
        case let .user(user):
            return user.displayName?.nilIfEmpty ?? user.username
        }
    }

    private var subtitle: String? {
        switch item {
        case let .restaurant(restaurant):
            return [restaurant.cuisine, restaurant.address]
                .compactMap { $0?.nilIfEmpty }
                .joined(separator: " • ")
                .nilIfEmpty
        case let .user(user):
            return "@\(user.username)"
        }
    }

    private var leadingIconName: String {
        switch item {
        case let .restaurant(restaurant):
            return cuisineIconName(for: restaurant.cuisine)
        case .user:
            return "person.crop.circle"
        }
    }

    private func cuisineIconName(for cuisine: String?) -> String {
        let normalized = (cuisine ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if normalized.contains("pizzeria") || normalized.contains("pizza") { return "takeoutbag.and.cup.and.straw.fill" }
        if normalized.contains("sushi") || normalized.contains("giapp") { return "fish.fill" }
        if normalized.contains("gelateria") || normalized.contains("gelato") { return "snowflake" }
        if normalized.contains("pasticceria") || normalized.contains("dolci") || normalized.contains("dessert") { return "birthday.cake.fill" }
        if normalized.contains("pub") || normalized.contains("birreria") { return "wineglass.fill" }
        if normalized.contains("bar") || normalized.contains("caff") || normalized.contains("coffee") { return "cup.and.saucer.fill" }
        if normalized.contains("enoteca") || normalized.contains("vino") { return "wineglass" }
        if normalized.contains("paninoteca") || normalized.contains("burger") || normalized.contains("fast") { return "takeoutbag.and.cup.and.straw" }
        if normalized.contains("braceria") || normalized.contains("grill") || normalized.contains("steak") { return "flame.fill" }
        if normalized.contains("pesce") || normalized.contains("seafood") { return "fish" }
        if normalized.contains("vegan") || normalized.contains("veget") { return "leaf.fill" }
        return "fork.knife.circle.fill"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: leadingIconName)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.indigo)
                .frame(width: 44, height: 44)
                .background(Color.indigo.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .padding(.top, 4)
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.72), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        }
    }
}

private struct SearchGlassCardModifier: ViewModifier {
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
    func searchGlassCard() -> some View {
        modifier(SearchGlassCardModifier())
    }
}
private extension String {
    var nilIfEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

