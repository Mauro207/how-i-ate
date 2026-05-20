import SwiftUI

struct RestaurantDetailView: View {
    @StateObject var viewModel: RestaurantDetailViewModel
    @State private var showReviewComposer = false
    @State private var editingReview: Review?
    @State private var deletingReview: Review?

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Caricamento dettaglio...")
            } else if let error = viewModel.errorMessage, viewModel.restaurant == nil {
                UnavailableStateView(title: "Errore", systemImage: "exclamationmark.triangle", message: error)
            } else {
                List {
                    if let restaurant = viewModel.restaurant {
                        Section("Dettaglio") {
                            Text(restaurant.name)
                                .font(.headline)
                            if let description = restaurant.description, !description.isEmpty {
                                Text(description)
                            }
                            if let cuisine = restaurant.cuisine, !cuisine.isEmpty {
                                Text("Cucina: \(cuisine)")
                                    .foregroundStyle(.secondary)
                            }
                            if let address = restaurant.address, !address.isEmpty {
                                Text(address)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Section("Recensioni") {
                        if viewModel.reviews.isEmpty {
                            Text("Nessuna recensione")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(viewModel.reviews) { review in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(review.user?.displayName ?? review.user?.username ?? "Utente")
                                        .font(.subheadline.bold())
                                    Text("Servizio: \(review.serviceRating, specifier: "%.1f") · Prezzo: \(review.priceRating, specifier: "%.1f") · Menu: \(review.menuRating, specifier: "%.1f")")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                    Text(review.comment)

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
