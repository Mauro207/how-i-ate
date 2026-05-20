import SwiftUI

struct RestaurantDetailView: View {
    @StateObject var viewModel: RestaurantDetailViewModel
    @State private var showReviewComposer = false
    @State private var editingReview: Review?
    @State private var deletingReview: Review?

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
                                            .frame(height: 200)
                                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    case .failure:
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(Color(.secondarySystemBackground))
                                            .frame(height: 200)
                                            .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
                                    default:
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(Color(.secondarySystemBackground))
                                            .frame(height: 200)
                                            .overlay(ProgressView())
                                    }
                                }
                                .listRowInsets(EdgeInsets())
                            }

                            Text(restaurant.name)
                                .font(.title3.weight(.bold))

                            if let description = restaurant.description, !description.isEmpty {
                                Text(description)
                                    .font(.body)
                            }

                            if let cuisine = restaurant.cuisine, !cuisine.isEmpty {
                                Label(cuisine, systemImage: "fork.knife")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            if let address = restaurant.address, !address.isEmpty {
                                Label(address, systemImage: "mappin.and.ellipse")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            if let createdAt = restaurant.createdAt, !createdAt.isEmpty {
                                Label("Creato il \(formattedDate(createdAt))", systemImage: "calendar")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            if let maps = restaurant.googleMapsUrl,
                               let mapsURL = URL(string: maps) {
                                Link(destination: mapsURL) {
                                    Label("Apri in mappe", systemImage: "map")
                                        .font(.subheadline.weight(.semibold))
                                }
                            }

                            if let instagram = restaurant.instagramUrl,
                               let instagramURL = URL(string: instagram) {
                                Link(destination: instagramURL) {
                                    Label("Apri Instagram", systemImage: "camera")
                                        .font(.subheadline.weight(.semibold))
                                }
                            }
                        } header: {
                            Text("Informazioni")
                        }

                        Section {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Valutazione media")
                                    .font(.subheadline.weight(.semibold))
                                Text("\(averageOverall, specifier: "%.2f") / 10")
                                    .font(.title2.weight(.bold))

                                HStack(spacing: 12) {
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
                            Text("Classifica locale")
                        }
                    }

                    Section("Recensioni") {
                        if viewModel.reviews.isEmpty {
                            Text("Nessuna recensione")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(viewModel.reviews) { review in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(review.user?.displayName ?? review.user?.username ?? "Utente")
                                            .font(.subheadline.bold())
                                        Spacer(minLength: 0)
                                        if let createdAt = review.createdAt, !createdAt.isEmpty {
                                            Text(formattedDate(createdAt))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }

                                    HStack(spacing: 8) {
                                        scorePill(title: "S", value: review.serviceRating)
                                        scorePill(title: "P", value: review.priceRating)
                                        scorePill(title: "M", value: review.menuRating)
                                    }

                                    Text(review.comment)
                                        .font(.body)

                                    if viewModel.isOwnReview(review) {
                                        HStack(spacing: 16) {
                                            Button("Modifica") {
                                                editingReview = review
                                            }

                                            Button("Elimina", role: .destructive) {
                                                deletingReview = review
                                            }
                                        }
                                        .font(.footnote)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(viewModel.restaurant?.name ?? "Ristorante")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Recensisci") {
                    showReviewComposer = true
                }
                .disabled(viewModel.isSubmittingReview)
            }
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .sheet(isPresented: $showReviewComposer) {
            ReviewComposerView(title: "Nuova recensione", isSubmitting: viewModel.isSubmittingReview) { s, p, m, c in
                await viewModel.submitReview(service: s, price: p, menu: m, comment: c)
                showReviewComposer = viewModel.errorMessage != nil
            }
            .presentationDetents([.medium, .large])
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

    private func formattedDate(_ isoDate: String) -> String {
        let parser = ISO8601DateFormatter()
        if let date = parser.date(from: isoDate) {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "it_IT")
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
        return isoDate
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
