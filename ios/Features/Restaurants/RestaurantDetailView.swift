import SwiftUI

struct RestaurantDetailView: View {
    @EnvironmentObject private var session: SessionManager
    @StateObject var viewModel: RestaurantDetailViewModel

    @State private var showReviewComposer = false
    @State private var showRestaurantEditor = false
    @State private var editingReview: Review?
    @State private var deletingReview: Review?
    @State private var expandedReviewIds: Set<String> = []

    private var canEditRestaurant: Bool {
        let role = session.currentUser?.role ?? ""
        return role == "admin" || role == "superadmin"
    }

    private var canModerateReviews: Bool {
        let role = session.currentUser?.role ?? ""
        return role == "admin" || role == "superadmin"
    }

    private var hasUserReviewed: Bool {
        guard let userId = session.currentUser?.id else { return false }
        return viewModel.reviews.contains { $0.user?.id == userId }
    }

    private var averageService: Double {
        guard !viewModel.reviews.isEmpty else { return 0 }
        return viewModel.reviews.map(\.serviceRating).reduce(0, +) / Double(viewModel.reviews.count)
    }

    private var averagePrice: Double {
        guard !viewModel.reviews.isEmpty else { return 0 }
        return viewModel.reviews.map(\.priceRating).reduce(0, +) / Double(viewModel.reviews.count)
    }

    private var averageMenu: Double {
        guard !viewModel.reviews.isEmpty else { return 0 }
        return viewModel.reviews.map(\.menuRating).reduce(0, +) / Double(viewModel.reviews.count)
    }

    private var averageOverall: Double {
        guard !viewModel.reviews.isEmpty else { return 0 }
        return (averageService + averagePrice + averageMenu) / 3
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Caricamento dettaglio...")
            } else if let error = viewModel.errorMessage, viewModel.restaurant == nil {
                UnavailableStateView(title: "Errore", systemImage: "exclamationmark.triangle", message: error)
            } else {
                List {
                    if let restaurant = viewModel.restaurant {
                        Section {
                            if let imageUrl = restaurant.coverImageUrl,
                               let url = URL(string: imageUrl) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case let .success(image):
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(height: 210)
                                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    case .failure:
                                        roundedPlaceholder(icon: "photo")
                                    default:
                                        roundedPlaceholder(icon: "photo")
                                            .overlay(ProgressView())
                                    }
                                }
                                .listRowInsets(EdgeInsets())
                            }

                            VStack(alignment: .leading, spacing: 10) {
                                Text(restaurant.name)
                                    .font(.title3.weight(.bold))

                                if let description = restaurant.description, !description.isEmpty {
                                    Text(description)
                                        .font(.body)
                                }

                                if let cuisine = restaurant.cuisine, !cuisine.isEmpty {
                                    detailLine("fork.knife", cuisine)
                                }

                                if let address = restaurant.address, !address.isEmpty {
                                    detailLine("mappin.and.ellipse", address)
                                }

                                if let createdAt = restaurant.createdAt, !createdAt.isEmpty {
                                    detailLine("calendar", "Creato il \(formattedDate(createdAt))")
                                }

                                HStack(spacing: 12) {
                                    if let maps = restaurant.googleMapsUrl,
                                       let mapsURL = URL(string: maps) {
                                        Link(destination: mapsURL) {
                                            linkChip("Apri mappe", "map")
                                        }
                                    }

                                    if let instagram = restaurant.instagramUrl,
                                       let instagramURL = URL(string: instagram) {
                                        Link(destination: instagramURL) {
                                            linkChip("Instagram", "camera")
                                        }
                                    }
                                }
                            }
                            .padding(14)
                            .background(Color.indigo.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        } header: {
                            Text("Informazioni luogo")
                        }

                        Section {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Valutazione media")
                                    .font(.subheadline.weight(.semibold))
                                Text("\(averageOverall, specifier: "%.2f") / 10")
                                    .font(.title2.weight(.bold))
                                    .foregroundStyle(.indigo)

                                HStack(spacing: 10) {
                                    scorePill(title: "Servizio", value: averageService)
                                    scorePill(title: "Prezzo", value: averagePrice)
                                    scorePill(title: "Menu", value: averageMenu)
                                }

                                Text("\(viewModel.reviews.count) recensioni")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        } header: {
                            Text("Valutazioni")
                        }
                    }

                    Section {
                        if !hasUserReviewed {
                            Button {
                                showReviewComposer = true
                            } label: {
                                Label("Lascia una recensione", systemImage: "plus.bubble")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 2)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .background(Color.indigo, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.clear)
                        }

                        if viewModel.reviews.isEmpty {
                            Text("Nessuna recensione presente. Lasciala per primo.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(viewModel.reviews) { review in
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack(alignment: .top) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(review.user?.displayName ?? review.user?.username ?? "Utente")
                                                .font(.subheadline.bold())
                                                .foregroundStyle(Color.indigo)

                                            if let createdAt = review.createdAt, !createdAt.isEmpty {
                                                Text(formattedDate(createdAt))
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }

                                            if let createdAt = review.createdAt,
                                               let updatedAt = review.updatedAt,
                                               !createdAt.isEmpty,
                                               !updatedAt.isEmpty,
                                               createdAt != updatedAt {
                                                Text("Modificata il \(formattedDate(updatedAt))")
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }

                                        Spacer(minLength: 8)

                                        Button {
                                            toggleReviewAccordion(review.id)
                                        } label: {
                                            HStack(spacing: 6) {
                                                Image(systemName: "star.fill")
                                                    .font(.caption)
                                                Text(formatRating(reviewAverage(review)))
                                                    .font(.footnote.weight(.semibold))
                                                Image(systemName: expandedReviewIds.contains(review.id) ? "chevron.up" : "chevron.down")
                                                    .font(.caption2)
                                            }
                                            .foregroundStyle(Color.indigo)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 7)
                                            .background(Color.indigo.opacity(0.12), in: Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }

                                    if expandedReviewIds.contains(review.id) {
                                        HStack(spacing: 10) {
                                            breakdownPill(title: "Servizio", value: review.serviceRating, color: .blue)
                                            breakdownPill(title: "Prezzo", value: review.priceRating, color: .green)
                                            breakdownPill(title: "Menu", value: review.menuRating, color: .purple)
                                        }
                                        .transition(.opacity.combined(with: .move(edge: .top)))
                                    }

                                    Text(review.comment)
                                        .font(.body)

                                    if viewModel.isOwnReview(review) {
                                        HStack(spacing: 12) {
                                            Button("Modifica") {
                                                editingReview = review
                                            }
                                            .buttonStyle(.bordered)
                                            .tint(.indigo)

                                            Button("Elimina", role: .destructive) {
                                                deletingReview = review
                                            }
                                            .buttonStyle(.bordered)
                                        }
                                        .font(.footnote.weight(.semibold))
                                    }
                                }
                                .padding(12)
                                .background(Color.indigo.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .listRowSeparator(.hidden)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    if canModerateReviews && !viewModel.isOwnReview(review) {
                                        Button {
                                            editingReview = review
                                        } label: {
                                            Label("Modifica", systemImage: "pencil")
                                        }
                                        .tint(.indigo)

                                        Button(role: .destructive) {
                                            deletingReview = review
                                        } label: {
                                            Label("Elimina", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("Recensioni")
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(
                    LinearGradient(
                        colors: [Color.indigo.opacity(0.12), Color(.systemBackground), Color(.systemBackground)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .navigationTitle(viewModel.restaurant?.name ?? "Ristorante")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if canEditRestaurant {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showRestaurantEditor = true
                    } label: {
                        if viewModel.isSavingRestaurant {
                            ProgressView()
                        } else {
                            Label("Modifica", systemImage: "pencil")
                        }
                    }
                    .disabled(viewModel.restaurant == nil || viewModel.isSavingRestaurant)
                }
            }
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load(forceRefresh: true) }
        .sheet(isPresented: $showReviewComposer) {
            ReviewComposerView(title: "Nuova recensione", isSubmitting: viewModel.isSubmittingReview) { s, p, m, c in
                await viewModel.submitReview(service: s, price: p, menu: m, comment: c)
                showReviewComposer = viewModel.errorMessage != nil
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showRestaurantEditor) {
            if let restaurant = viewModel.restaurant {
                RestaurantEditSheetView(
                    restaurant: restaurant,
                    isSaving: viewModel.isSavingRestaurant
                ) { payload in
                    let success = await viewModel.updateRestaurant(payload: payload)
                    if success {
                        showRestaurantEditor = false
                    }
                }
                .presentationDetents([.large])
            }
        }
        .sheet(item: $editingReview) { review in
            ReviewComposerView(
                title: "Modifica recensione",
                initialService: review.serviceRating,
                initialPrice: review.priceRating,
                initialMenu: review.menuRating,
                initialComment: review.comment,
                isSubmitting: viewModel.isSubmittingReview
            ) { s, p, m, c in
                await viewModel.updateReview(reviewId: review.id, service: s, price: p, menu: m, comment: c)
                if viewModel.errorMessage == nil {
                    editingReview = nil
                }
            }
            .presentationDetents([.medium, .large])
        }
        .confirmationDialog(
            "Confermi eliminazione recensione?",
            isPresented: Binding(
                get: { deletingReview != nil },
                set: { if !$0 { deletingReview = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Elimina", role: .destructive) {
                if let review = deletingReview {
                    Task {
                        await viewModel.deleteReview(reviewId: review.id)
                        deletingReview = nil
                    }
                }
            }
            Button("Annulla", role: .cancel) {
                deletingReview = nil
            }
        }
    }

    @ViewBuilder
    private func roundedPlaceholder(icon: String) -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color(.secondarySystemBackground))
            .frame(height: 210)
            .overlay(Image(systemName: icon).foregroundStyle(.secondary))
    }

    @ViewBuilder
    private func detailLine(_ icon: String, _ text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func linkChip(_ title: String, _ icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.indigo.opacity(0.14), in: Capsule())
    }

    @ViewBuilder
    private func scorePill(title: String, value: Double) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("\(value, specifier: "%.1f")")
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color(.secondarySystemBackground), in: Capsule())
    }

    @ViewBuilder
    private func breakdownPill(title: String, value: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(formatRating(value))
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func reviewAverage(_ review: Review) -> Double {
        (review.serviceRating + review.priceRating + review.menuRating) / 3
    }

    private func toggleReviewAccordion(_ reviewId: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if expandedReviewIds.contains(reviewId) {
                expandedReviewIds.remove(reviewId)
            } else {
                expandedReviewIds.insert(reviewId)
            }
        }
    }

    private func formatRating(_ rating: Double) -> String {
        let rounded = (rating * 4).rounded() / 4
        let whole = floor(rounded)
        let remainder = (rounded - whole).rounded(toPlaces: 2)

        if remainder == 0.25 {
            return "\(Int(whole))+"
        }
        if remainder == 0.75 {
            return "\(Int(whole) + 1)-"
        }

        return String(format: "%.1f", rounded)
    }

    private func formattedDate(_ isoDate: String) -> String {
        DateDisplayFormatter.fromISO(isoDate)
    }
}

private struct RestaurantEditSheetView: View {
    let restaurant: Restaurant
    let isSaving: Bool
    let onSave: (RestaurantMutationPayload) async -> Void

    @State private var name: String
    @State private var description: String
    @State private var address: String
    @State private var cuisine: String
    @State private var coverImageUrl: String
    @State private var googleMapsUrl: String
    @State private var instagramUrl: String

    init(restaurant: Restaurant, isSaving: Bool, onSave: @escaping (RestaurantMutationPayload) async -> Void) {
        self.restaurant = restaurant
        self.isSaving = isSaving
        self.onSave = onSave
        _name = State(initialValue: restaurant.name)
        _description = State(initialValue: restaurant.description ?? "")
        _address = State(initialValue: restaurant.address ?? "")
        _cuisine = State(initialValue: restaurant.cuisine ?? "")
        _coverImageUrl = State(initialValue: restaurant.coverImageUrl ?? "")
        _googleMapsUrl = State(initialValue: restaurant.googleMapsUrl ?? "")
        _instagramUrl = State(initialValue: restaurant.instagramUrl ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Base") {
                    TextField("Nome", text: $name)
                    TextField("Descrizione", text: $description, axis: .vertical)
                    TextField("Indirizzo", text: $address)
                    TextField("Cucina", text: $cuisine)
                }

                Section("Link") {
                    TextField("Cover image URL", text: $coverImageUrl)
                        .textInputAutocapitalization(.never)
                    TextField("Google Maps URL", text: $googleMapsUrl)
                        .textInputAutocapitalization(.never)
                    TextField("Instagram URL", text: $instagramUrl)
                        .textInputAutocapitalization(.never)
                }

                Section {
                    Button {
                        Task {
                            await onSave(
                                RestaurantMutationPayload(
                                    name: name.trimmed,
                                    description: description.nilIfEmpty,
                                    address: address.nilIfEmpty,
                                    cuisine: cuisine.nilIfEmpty,
                                    coverImageUrl: coverImageUrl.nilIfEmpty,
                                    googleMapsUrl: googleMapsUrl.nilIfEmpty,
                                    instagramUrl: instagramUrl.nilIfEmpty
                                )
                            )
                        }
                    } label: {
                        if isSaving {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Salva modifiche")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(name.trimmed.isEmpty || isSaving)
                }
            }
            .navigationTitle("Modifica luogo")
        }
    }
}

private struct ReviewComposerView: View {
    let title: String
    let initialService: Double
    let initialPrice: Double
    let initialMenu: Double
    let initialComment: String
    let isSubmitting: Bool
    let onSubmit: (_ service: Double, _ price: Double, _ menu: Double, _ comment: String) async -> Void

    @State private var service: Double
    @State private var price: Double
    @State private var menu: Double
    @State private var comment: String

    init(
        title: String,
        initialService: Double = 7.0,
        initialPrice: Double = 7.0,
        initialMenu: Double = 7.0,
        initialComment: String = "",
        isSubmitting: Bool,
        onSubmit: @escaping (_ service: Double, _ price: Double, _ menu: Double, _ comment: String) async -> Void
    ) {
        self.title = title
        self.initialService = initialService
        self.initialPrice = initialPrice
        self.initialMenu = initialMenu
        self.initialComment = initialComment
        self.isSubmitting = isSubmitting
        self.onSubmit = onSubmit
        _service = State(initialValue: initialService)
        _price = State(initialValue: initialPrice)
        _menu = State(initialValue: initialMenu)
        _comment = State(initialValue: initialComment)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Valutazioni") {
                    Slider(value: $service, in: 0 ... 10, step: 0.5) {
                        Text("Servizio")
                    }
                    Text("Servizio: \(service, specifier: "%.1f")")

                    Slider(value: $price, in: 0 ... 10, step: 0.5) {
                        Text("Prezzo")
                    }
                    Text("Prezzo: \(price, specifier: "%.1f")")

                    Slider(value: $menu, in: 0 ... 10, step: 0.5) {
                        Text("Menu")
                    }
                    Text("Menu: \(menu, specifier: "%.1f")")
                }

                Section("Commento") {
                    TextEditor(text: $comment)
                        .frame(minHeight: 120)
                }

                Section {
                    Button {
                        Task {
                            await onSubmit(service, price, menu, comment)
                        }
                    } label: {
                        if isSubmitting {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Invia recensione")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(isSubmitting)
                }
            }
            .navigationTitle(title)
        }
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var nilIfEmpty: String? {
        let value = trimmed
        return value.isEmpty ? nil : value
    }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        guard places >= 0 else { return self }
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
