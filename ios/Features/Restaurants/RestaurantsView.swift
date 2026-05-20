import SwiftUI

struct RestaurantsView: View {
    @EnvironmentObject private var session: SessionManager
    @StateObject var viewModel: RestaurantsViewModel
    @State private var showSuggestSheet = false

    private var isAdminOrSuperAdmin: Bool {
        let role = session.currentUser?.role ?? ""
        return role == "admin" || role == "superadmin"
    }

    private var displayName: String {
        session.currentUser?.displayName ?? session.currentUser?.username ?? "Utente"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16, pinnedViews: []) {
                    HomeHeroCard(
                        username: displayName,
                        isAdmin: isAdminOrSuperAdmin,
                        onPrimaryAction: {
                            if isAdminOrSuperAdmin {
                                // Per admin il flusso di creazione resta nel pannello admin.
                            } else {
                                showSuggestSheet = true
                            }
                        }
                    )

                    if isAdminOrSuperAdmin {
                        NavigationLink {
                            AdminRestaurantsView(
                                viewModel: AdminRestaurantsViewModel(service: viewModel.restaurantService)
                            )
                        } label: {
                            Label("Apri gestione ristoranti", systemImage: "slider.horizontal.3")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.indigo.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }

                    if viewModel.isLoading {
                        ProgressView("Caricamento homepage...")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 24)
                    } else if let error = viewModel.errorMessage {
                        UnavailableStateView(title: "Errore", systemImage: "exclamationmark.triangle", message: error)
                            .frame(height: 220)
                    } else {
                        if viewModel.recentRestaurants.isEmpty {
                            UnavailableStateView(title: "Nessun luogo trovato", systemImage: "fork.knife.circle", message: "Aggiungi o suggerisci il primo ristorante")
                                .frame(height: 220)
                        } else {
                            HomeSectionTitle(title: "Ultimi luoghi", subtitle: "Recensisci i luoghi creati di recente")

                            VStack(spacing: 10) {
                                ForEach(viewModel.recentRestaurants.prefix(8)) { restaurant in
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

                        if !viewModel.topRankings.isEmpty {
                            HomeSectionTitle(title: "Top ranking", subtitle: "I migliori luoghi del momento")

                            VStack(spacing: 10) {
                                ForEach(Array(viewModel.topRankings.enumerated()), id: \.element.restaurantId) { index, item in
                                    HStack(spacing: 12) {
                                        Text("#\(index + 1)")
                                            .font(.headline)
                                            .frame(width: 34)

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
            .navigationTitle("Home")
            .refreshable { await viewModel.load() }
            .task { await viewModel.load() }
            .sheet(isPresented: $showSuggestSheet) {
                SuggestPlaceView(viewModel: viewModel)
                    .presentationDetents([.large])
            }
        }
    }
}

private struct HomeHeroCard: View {
    let username: String
    let isAdmin: Bool
    let onPrimaryAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Ciao \(username) 👋")
                .font(.title3.weight(.bold))
            Text("Esplora e recensisci gli ultimi luoghi aggiunti.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button(action: onPrimaryAction) {
                Label(isAdmin ? "Gestione admin" : "Suggerisci luogo", systemImage: isAdmin ? "building.2.crop.circle" : "plus.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)
        }
        .padding(18)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
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

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.indigo.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: "fork.knife")
                    .foregroundStyle(Color.indigo)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(restaurant.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                if let cuisine = restaurant.cuisine, !cuisine.isEmpty {
                    Text(cuisine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

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

private struct SuggestPlaceView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: RestaurantsViewModel

    @State private var name = ""
    @State private var description = ""
    @State private var address = ""
    @State private var cuisine = ""
    @State private var mapsUrl = ""
    @State private var instagramUrl = ""
    @State private var serviceRating = 7.0
    @State private var priceRating = 7.0
    @State private var menuRating = 7.0
    @State private var comment = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Luogo") {
                    TextField("Nome", text: $name)
                    TextField("Descrizione", text: $description, axis: .vertical)
                    TextField("Indirizzo", text: $address)
                    TextField("Cucina", text: $cuisine)
                }

                Section("Link") {
                    TextField("Google Maps URL", text: $mapsUrl)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Instagram URL", text: $instagramUrl)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section("Prima recensione") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Servizio: \(serviceRating, specifier: "%.1f")")
                        Slider(value: $serviceRating, in: 0 ... 10, step: 0.5)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Prezzo: \(priceRating, specifier: "%.1f")")
                        Slider(value: $priceRating, in: 0 ... 10, step: 0.5)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Menu: \(menuRating, specifier: "%.1f")")
                        Slider(value: $menuRating, in: 0 ... 10, step: 0.5)
                    }
                    TextEditor(text: $comment)
                        .frame(minHeight: 90)
                }

                if let message = viewModel.suggestionMessage {
                    Section {
                        Text(message)
                            .foregroundStyle(message.lowercased().contains("successo") ? .green : .red)
                    }
                }

                Section {
                    Button {
                        Task {
                            await viewModel.createSuggestion(
                                name: name,
                                description: description,
                                address: address,
                                cuisine: cuisine,
                                googleMapsUrl: mapsUrl,
                                instagramUrl: instagramUrl,
                                serviceRating: serviceRating,
                                priceRating: priceRating,
                                menuRating: menuRating,
                                comment: comment
                            )
                            if (viewModel.suggestionMessage ?? "").lowercased().contains("successo") {
                                dismiss()
                            }
                        }
                    } label: {
                        if viewModel.isSubmittingSuggestion {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Invia suggerimento")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(viewModel.isSubmittingSuggestion)
                }
            }
            .navigationTitle("Suggerisci luogo")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Chiudi") { dismiss() }
                }
            }
        }
    }
}
