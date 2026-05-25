import SwiftUI

struct RestaurantDetailView: View {
    @EnvironmentObject private var session: SessionManager
    @StateObject var viewModel: RestaurantDetailViewModel

    @State private var showReviewComposer = false
    @State private var showRestaurantEditor = false
    @State private var restaurantEditorErrorMessage: String?
    @State private var editingReview: Review?
    @State private var deletingReview: Review?
    @State private var expandedReviewIds: Set<String> = []
    @State private var reviewSuccessMessage: String?

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

    private var averageOverallDisplay: String {
        formatRating(averageOverall)
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
                                            .frame(height: 220)
                                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                    case .failure:
                                        roundedPlaceholder(icon: "photo")
                                    default:
                                        roundedPlaceholder(icon: "photo")
                                            .overlay(ProgressView())
                                    }
                                }
                                .overlay(alignment: .topTrailing) {
                                    averageRatingBadge
                                        .padding(12)
                                }
                                .listRowInsets(EdgeInsets())
                            }

                            VStack(alignment: .leading, spacing: 16) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(restaurant.name)
                                        .font(.title2.weight(.bold))
                                        .foregroundStyle(.primary)
                                        .fixedSize(horizontal: false, vertical: true)

                                    if let description = restaurant.description, !description.isEmpty {
                                        Text(description)
                                            .font(.body)
                                            .foregroundStyle(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }

                                VStack(alignment: .leading, spacing: 10) {
                                    if let cuisine = restaurant.cuisine, !cuisine.isEmpty {
                                        detailLine("fork.knife", cuisine)
                                    }

                                    if let address = restaurant.address, !address.isEmpty {
                                        detailLine("mappin.and.ellipse", address)
                                    }
                                }

                                if hasExternalLinks(restaurant) {
                                    HStack(spacing: 12) {
                                        if let maps = restaurant.googleMapsUrl,
                                           let mapsURL = URL(string: maps) {
                                            Link(destination: mapsURL) {
                                                linkChip("Google Maps", "map")
                                            }
                                            .frame(maxWidth: .infinity)
                                        }

                                        if let instagram = restaurant.instagramUrl,
                                           let instagramURL = URL(string: instagram) {
                                            Link(destination: instagramURL) {
                                                linkChip("Instagram", "camera")
                                            }
                                            .frame(maxWidth: .infinity)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.top, 2)
                                }
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                            }
                        } header: {
                            Text("Informazioni luogo")
                        }

                    }

                    Section {
                        if let reviewSuccessMessage {
                            reviewSuccessBanner(reviewSuccessMessage)
                                .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                                .listRowBackground(Color.clear)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        if !hasUserReviewed {
                            Button {
                                reviewSuccessMessage = nil
                                showReviewComposer = true
                            } label: {
                                Label("Lascia una recensione", systemImage: "plus.bubble")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 14)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .reviewPrimaryButtonBackground()
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.clear)
                        }

                        if viewModel.reviews.isEmpty {
                            Text("Nessuna recensione presente. Lasciala per primo.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .reviewGlassCard()
                                .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                                .listRowBackground(Color.clear)
                        } else {
                            ForEach(viewModel.reviews) { review in
                                reviewCard(review)
                                    .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                                    .listRowBackground(Color.clear)
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
                        restaurantEditorErrorMessage = nil
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
                let success = await viewModel.submitReview(service: s, price: p, menu: m, comment: c)
                showReviewComposer = !success
                if success {
                    showReviewSuccess("Recensione pubblicata")
                }
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showRestaurantEditor) {
            if let restaurant = viewModel.restaurant {
                RestaurantEditSheetView(
                    restaurant: restaurant,
                    isSaving: viewModel.isSavingRestaurant,
                    apiErrorMessage: $restaurantEditorErrorMessage
                ) { payload in
                    restaurantEditorErrorMessage = nil
                    let success = await viewModel.updateRestaurant(payload: payload)
                    if success {
                        showRestaurantEditor = false
                    } else {
                        restaurantEditorErrorMessage = viewModel.errorMessage
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
                let success = await viewModel.updateReview(reviewId: review.id, service: s, price: p, menu: m, comment: c)
                if success {
                    editingReview = nil
                    showReviewSuccess("Recensione aggiornata")
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

    private func reviewCard(_ review: Review) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(review.user?.displayName ?? review.user?.username ?? "Utente")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

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
                            .font(.caption.weight(.semibold))
                        Text(formatRating(reviewAverage(review)))
                            .font(.footnote.weight(.semibold))
                        Image(systemName: expandedReviewIds.contains(review.id) ? "chevron.up" : "chevron.down")
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(Color.indigo)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 8)
                    .background(Color.indigo.opacity(0.11), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Mostra dettagli valutazione")
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
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            if viewModel.isOwnReview(review) {
                HStack(spacing: 10) {
                    reviewActionButton("Modifica", systemImage: "pencil", color: .indigo) {
                        reviewSuccessMessage = nil
                        editingReview = review
                    }

                    reviewActionButton("Elimina", systemImage: "trash", color: .red) {
                        reviewSuccessMessage = nil
                        deletingReview = review
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(14)
        .reviewGlassCard()
    }

    @ViewBuilder
    private func roundedPlaceholder(icon: String) -> some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color(.secondarySystemBackground))
            .frame(height: 220)
            .overlay(Image(systemName: icon).foregroundStyle(.secondary))
    }

    @ViewBuilder
    private var averageRatingBadge: some View {
        if #available(iOS 26.0, *) {
            averageRatingBadgeContent
                .glassEffect(.regular.tint(.indigo.opacity(0.18)), in: .capsule)
        } else {
            averageRatingBadgeContent
                .background(.ultraThinMaterial, in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(Color.white.opacity(0.34), lineWidth: 1)
                }
        }
    }

    private var averageRatingBadgeContent: some View {
        HStack(spacing: 6) {
            Image(systemName: "star.fill")
                .font(.caption.weight(.bold))
            Text(averageOverallDisplay)
                .font(.subheadline.weight(.bold))
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func hasExternalLinks(_ restaurant: Restaurant) -> Bool {
        let mapsURL = restaurant.googleMapsUrl.flatMap(URL.init(string:))
        let instagramURL = restaurant.instagramUrl.flatMap(URL.init(string:))
        return mapsURL != nil || instagramURL != nil
    }

    @ViewBuilder
    private func detailLine(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.indigo)
                .frame(width: 28, height: 28)
                .background(Color.indigo.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func linkChip(_ title: String, _ icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.indigo)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.indigo.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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

    private func reviewActionButton(_ title: String, systemImage: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(color)
        .background(color.opacity(0.11), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(color.opacity(0.16), lineWidth: 1)
        }
    }

    private func reviewSuccessBanner(_ message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(.green)

            VStack(alignment: .leading, spacing: 2) {
                Text(message)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("Le modifiche sono state salvate correttamente.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    reviewSuccessMessage = nil
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 30)
                    .background(Color.primary.opacity(0.06), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Chiudi conferma")
        }
        .padding(14)
        .background(Color.green.opacity(0.11), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.green.opacity(0.18), lineWidth: 1)
        }
    }

    private func showReviewSuccess(_ message: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            reviewSuccessMessage = message
        }

        Task {
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            await MainActor.run {
                guard reviewSuccessMessage == message else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    reviewSuccessMessage = nil
                }
            }
        }
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
        DateDisplayFormatter.reviewDate(fromISO: isoDate)
    }
}

private struct RestaurantEditSheetView: View {
    @Environment(\.dismiss) private var dismiss

    let restaurant: Restaurant
    let isSaving: Bool
    let onSave: (RestaurantMutationPayload) async -> Void

    @Binding var apiErrorMessage: String?

    private var cuisineOptions: [String] {
        guard !cuisine.isEmpty, !PlaceTypeOptions.all.contains(cuisine) else {
            return PlaceTypeOptions.all
        }

        return [cuisine] + PlaceTypeOptions.all
    }

    @State private var name: String
    @State private var description: String
    @State private var address: String
    @State private var cuisine: String
    @State private var coverImageUrl: String
    @State private var googleMapsUrl: String
    @State private var instagramUrl: String
    @State private var validationMessage: String?

    init(
        restaurant: Restaurant,
        isSaving: Bool,
        apiErrorMessage: Binding<String?>,
        onSave: @escaping (RestaurantMutationPayload) async -> Void
    ) {
        self.restaurant = restaurant
        self.isSaving = isSaving
        self.onSave = onSave
        _apiErrorMessage = apiErrorMessage
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
                Section("Informazioni sul luogo") {
                    TextField("Nome", text: $name)
                    TextField("Descrizione", text: $description, axis: .vertical)
                    TextField("Indirizzo", text: $address)
                    Picker("Tipo di luogo", selection: $cuisine) {
                        Text("Seleziona tipo di luogo").tag("")
                        ForEach(cuisineOptions, id: \.self) { item in
                            Text(item).tag(item)
                        }
                    }
                }

                Section {
                    TextField("Cover image URL", text: $coverImageUrl)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .onChange(of: coverImageUrl) { _ in clearLinkErrors() }
                    TextField("Google Maps URL", text: $googleMapsUrl)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .onChange(of: googleMapsUrl) { _ in clearLinkErrors() }
                    TextField("Instagram URL", text: $instagramUrl)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .onChange(of: instagramUrl) { _ in clearLinkErrors() }
                } header: {
                    Text("Link aggiuntivi")
                } footer: {
                    Text("Usa link completi, ad esempio https://maps.google.com/... o https://www.instagram.com/...")
                }

                if let visibleErrorMessage {
                    Section {
                        Label {
                            Text(visibleErrorMessage)
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill")
                        }
                        .font(.footnote)
                        .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Modifica luogo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Chiudi")
                    .disabled(isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await saveRestaurant() }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Salva")
                        }
                    }
                    .disabled(name.trimmed.isEmpty || isSaving)
                }
            }
        }
    }

    private var visibleErrorMessage: String? {
        validationMessage ?? normalizedAPIErrorMessage
    }

    private var normalizedAPIErrorMessage: String? {
        guard let apiErrorMessage else { return nil }
        let lowercased = apiErrorMessage.lowercased()

        if lowercased.contains("instagram") {
            return "Il link Instagram non e valido. Controlla che inizi con https://www.instagram.com/."
        }

        if lowercased.contains("google") || lowercased.contains("maps") || lowercased.contains("googlemaps") {
            return "Il link Google Maps non e valido. Controlla che sia un URL completo di Google Maps."
        }

        if lowercased.contains("url") || lowercased.contains("link") {
            return "Uno dei link inseriti non e valido. Controlla Google Maps, Instagram e copertina."
        }

        return apiErrorMessage
    }

    private func saveRestaurant() async {
        validationMessage = validateURLs()
        guard validationMessage == nil else { return }

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

    private func clearLinkErrors() {
        validationMessage = nil
        apiErrorMessage = nil
    }

    private func validateURLs() -> String? {
        if let validation = RestaurantURLValidator.googleMapsValidationMessage(for: googleMapsUrl) {
            return validation
        }

        if let validation = RestaurantURLValidator.instagramValidationMessage(for: instagramUrl) {
            return validation
        }

        if let validation = RestaurantURLValidator.validationMessage(for: coverImageUrl, kind: "Copertina") {
            return validation
        }

        return nil
    }
}

private struct ReviewComposerView: View {
    @Environment(\.dismiss) private var dismiss

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
            ScrollView {
                VStack(spacing: 18) {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Valutazioni")
                                .font(.title3.weight(.bold))
                            Text("Dai un voto da 0 a 10 per ogni categoria.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        ratingSlider(title: "Servizio", value: $service, color: .blue)
                        ratingSlider(title: "Prezzo", value: $price, color: .green)
                        ratingSlider(title: "Menu", value: $menu, color: .purple)
                    }
                    .padding(16)
                    .reviewComposerGlassCard()

                    VStack(alignment: .leading, spacing: 10) {
                        Label("Commento", systemImage: "text.bubble")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)

                        TextEditor(text: $comment)
                            .frame(minHeight: 130)
                            .scrollContentBackground(.hidden)
                            .padding(12)
                            .background(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.72), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.primary.opacity(0.07), lineWidth: 1)
                            }
                    }
                    .padding(16)
                    .reviewComposerGlassCard()

                    Button {
                        Task {
                            await onSubmit(service, price, menu, comment)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if isSubmitting {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text(isSubmitting ? "Invio in corso..." : "Invia recensione")
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(isSubmitting)
                    .opacity(isSubmitting ? 0.72 : 1)
                    .reviewComposerPrimaryButtonBackground()
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
            .background(
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
            )
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .disabled(isSubmitting)
                    .accessibilityLabel("Chiudi")
                }
            }
        }
    }

    private func ratingSlider(title: String, value: Binding<Double>, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(formatSliderValue(value.wrappedValue))
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(color.opacity(0.12), in: Capsule())
            }

            Slider(value: value, in: 0 ... 10, step: 0.5) {
                Text(title)
            }
            .tint(color)
        }
    }

    private func formatSliderValue(_ value: Double) -> String {
        String(format: "%.1f", value)
    }
}

private struct ReviewGlassCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular.tint(.indigo.opacity(0.06)), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        } else {
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.primary.opacity(0.07), lineWidth: 1)
                }
        }
    }
}

private struct ReviewPrimaryButtonBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular.tint(.indigo).interactive(), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        } else {
            content
                .background(Color.indigo, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

private struct ReviewComposerGlassCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular.tint(.indigo.opacity(0.06)), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        } else {
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.primary.opacity(0.07), lineWidth: 1)
                }
        }
    }
}

private struct ReviewComposerPrimaryButtonBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular.tint(.indigo).interactive(), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        } else {
            content
                .background(Color.indigo, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
}

private extension View {
    func reviewGlassCard() -> some View {
        modifier(ReviewGlassCardModifier())
    }

    func reviewPrimaryButtonBackground() -> some View {
        modifier(ReviewPrimaryButtonBackgroundModifier())
    }

    func reviewComposerGlassCard() -> some View {
        modifier(ReviewComposerGlassCardModifier())
    }

    func reviewComposerPrimaryButtonBackground() -> some View {
        modifier(ReviewComposerPrimaryButtonBackgroundModifier())
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
