import SwiftUI

struct AddSuggestionTabView: View {
    @EnvironmentObject private var session: SessionManager
    let service: SuggestionService
    let restaurantService: RestaurantService
    let reviewService: ReviewService

    private let defaultRating = 5.0
    private let minRating = 0.25
    private let maxRating = 10.0
    private let ratingStep = 0.25

    @State private var name = ""
    @State private var description = ""
    @State private var address = ""
    @State private var cuisine = ""
    @State private var mapsUrl = ""
    @State private var instagramUrl = ""

    @State private var serviceRating = 5.0
    @State private var priceRating = 5.0
    @State private var menuRating = 5.0
    @State private var comment = ""

    @State private var isSubmitting = false
    @State private var success = false
    @State private var errorMessage: String?

    @State private var checkingDuplicate = false
    @State private var similarRestaurants: [Restaurant] = []
    @State private var showDuplicateWarning = false

    @State private var loadingGooglePlaces = false
    @State private var googleSuggestions: [GooglePlaceSuggestion] = []

    @FocusState private var isNameFieldFocused: Bool

    private let cuisineOptions = ["Pizzeria", "Ristorante", "Pub", "Paninoteca", "Bar", "Braceria", "Enoteca", "Sushi"]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Suggerisci un luogo")
                            .font(.title3.weight(.bold))
                        Text("Suggerisci un nuovo luogo. La tua proposta sara revisionata dagli amministratori.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                if success {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Suggerimento inviato con successo")
                                .font(.headline)
                                .foregroundStyle(.indigo)
                            Text("Il tuo suggerimento e stato ricevuto e sara revisionato dagli amministratori.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }

                if !success {
                    Section("Informazioni luogo") {
                        TextField("Nome luogo", text: $name)
                            .focused($isNameFieldFocused)
                            .onSubmit {
                                Task { await checkForDuplicatesAndSuggestions() }
                            }

                        if checkingDuplicate {
                            ProgressView("Verifico se il luogo esiste gia...")
                                .font(.caption)
                        }

                        if showDuplicateWarning {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(alignment: .top, spacing: 8) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundStyle(.orange)
                                        Text("Forse e gia presente")
                                            .font(.subheadline.weight(.semibold))
                                    }

                                    Spacer(minLength: 0)

                                    Button {
                                        dismissDuplicateWarning()
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(.secondary)
                                            .padding(5)
                                            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Chiudi avviso duplicati")
                                }

                                Text("Abbiamo trovato \(similarRestaurants.count) luogo/i simile/i gia presente/i.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                ForEach(similarRestaurants.prefix(5)) { restaurant in
                                    NavigationLink {
                                        RestaurantDetailView(
                                            viewModel: RestaurantDetailViewModel(
                                                restaurantId: restaurant.id,
                                                restaurantService: restaurantService,
                                                reviewService: reviewService,
                                                currentUserId: session.currentUser?.id
                                            )
                                        )
                                    } label: {
                                        HStack(spacing: 10) {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(restaurant.name)
                                                    .font(.footnote.weight(.semibold))
                                                    .foregroundStyle(.primary)
                                                Text([restaurant.cuisine, restaurant.address]
                                                    .compactMap { $0?.nilIfEmpty }
                                                    .joined(separator: " · "))
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }

                                            Spacer(minLength: 0)

                                            Image(systemName: "chevron.right")
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(.tertiary)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.vertical, 4)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
                        }

                        if !showDuplicateWarning, loadingGooglePlaces {
                            ProgressView("Cerco suggerimenti su Google Maps...")
                                .font(.caption)
                        }

                        if !showDuplicateWarning, !googleSuggestions.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Suggerimenti Google Maps")
                                    .font(.subheadline.weight(.semibold))

                                ForEach(googleSuggestions) { suggestion in
                                    Button {
                                        Task { await selectGoogleSuggestion(suggestion) }
                                    } label: {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(suggestion.mainText)
                                                .font(.footnote.weight(.semibold))
                                            Text(suggestion.secondaryText.isEmpty ? suggestion.description : suggestion.secondaryText)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
                        }

                        Picker("Tipo di luogo", selection: $cuisine) {
                            Text("Seleziona tipo di luogo").tag("")
                            ForEach(cuisineOptions, id: \.self) { item in
                                Text(item).tag(item)
                            }
                        }

                        TextField("Indirizzo", text: $address)
                        TextField("Profilo Instagram", text: $instagramUrl)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        TextField("Descrizione", text: $description, axis: .vertical)
                    }

                    Section("La tua recensione") {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Servizio: \(formatRating(serviceRating)) / \(maxRating, specifier: "%.1f")")
                            Slider(value: $serviceRating, in: minRating ... maxRating, step: ratingStep)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Prezzo: \(formatRating(priceRating)) / \(maxRating, specifier: "%.1f")")
                            Slider(value: $priceRating, in: minRating ... maxRating, step: ratingStep)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Menu: \(formatRating(menuRating)) / \(maxRating, specifier: "%.1f")")
                            Slider(value: $menuRating, in: minRating ... maxRating, step: ratingStep)
                        }

                        TextEditor(text: $comment)
                            .frame(minHeight: 120)

                        if !comment.trimmed.isEmpty, comment.trimmed.count < 5 {
                            Text("Il commento deve avere almeno 5 caratteri")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }

                    Section {
                        Button {
                            Task { await submitSuggestion() }
                        } label: {
                            if isSubmitting {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            } else {
                                Text("Invia suggerimento")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .disabled(isSubmitting)
                    }
                }
            }
            .navigationTitle("Suggerisci")
            .onChange(of: name) { newValue in
                if newValue.trimmed.count < 2 {
                    similarRestaurants = []
                    showDuplicateWarning = false
                    googleSuggestions = []
                }
            }
            .onChange(of: isNameFieldFocused) { focused in
                guard !focused else { return }
                Task { await checkForDuplicatesAndSuggestions() }
            }
        }
    }

    private func submitSuggestion() async {
        errorMessage = nil

        let trimmedName = name.trimmed
        let trimmedComment = comment.trimmed

        guard !trimmedName.isEmpty else {
            errorMessage = "Il nome del luogo e obbligatorio."
            return
        }

        guard trimmedComment.count >= 5 else {
            errorMessage = "Compila tutti i campi della recensione (commento minimo 5 caratteri)."
            return
        }

        if let validation = validateURLField(instagramUrl, kind: "Instagram") {
            errorMessage = validation
            return
        }

        if let validation = validateURLField(mapsUrl, kind: "Google Maps") {
            errorMessage = validation
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            _ = try await service.createSuggestion(
                payload: CreateSuggestionPayload(
                    name: trimmedName,
                    description: description.nilIfEmpty,
                    address: address.nilIfEmpty,
                    cuisine: cuisine.nilIfEmpty,
                    googleMapsUrl: mapsUrl.nilIfEmpty,
                    instagramUrl: instagramUrl.nilIfEmpty,
                    review: SuggestionReviewPayload(
                        serviceRating: serviceRating,
                        priceRating: priceRating,
                        menuRating: menuRating,
                        comment: trimmedComment
                    )
                )
            )

            success = true
            clearForm()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func checkForDuplicatesAndSuggestions() async {
        let query = name.trimmed
        guard query.count >= 2 else {
            similarRestaurants = []
            showDuplicateWarning = false
            googleSuggestions = []
            return
        }

        checkingDuplicate = true
        defer { checkingDuplicate = false }

        do {
            let matches = try await restaurantService.searchRestaurants(query: query)
            similarRestaurants = matches
            showDuplicateWarning = !matches.isEmpty

            if matches.isEmpty {
                await loadGoogleSuggestions(query: query)
            } else {
                googleSuggestions = []
            }
        } catch {
            similarRestaurants = []
            showDuplicateWarning = false
            googleSuggestions = []
        }
    }

    private func loadGoogleSuggestions(query: String) async {
        loadingGooglePlaces = true
        defer { loadingGooglePlaces = false }

        do {
            googleSuggestions = try await restaurantService.getGooglePlaceSuggestions(query: query)
        } catch {
            // For regular users this endpoint may be forbidden; keep UI silent.
            googleSuggestions = []
        }
    }

    private func selectGoogleSuggestion(_ suggestion: GooglePlaceSuggestion) async {
        loadingGooglePlaces = true
        defer { loadingGooglePlaces = false }

        do {
            let place = try await restaurantService.getGooglePlaceDetails(placeId: suggestion.placeId)
            name = place.name.trimmed.isEmpty ? suggestion.mainText : place.name.trimmed
            if !place.city.trimmed.isEmpty {
                address = place.city.trimmed
            }
            if !place.mapsUrl.trimmed.isEmpty {
                mapsUrl = place.mapsUrl.trimmed
            }
            googleSuggestions = []
        } catch {
            googleSuggestions = []
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

    private func validateURLField(_ value: String, kind: String) -> String? {
        let trimmed = value.trimmed
        guard !trimmed.isEmpty else { return nil }
        guard let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            return "URL \(kind) non valido"
        }
        return nil
    }

    private func clearForm() {
        name = ""
        description = ""
        address = ""
        cuisine = ""
        mapsUrl = ""
        instagramUrl = ""
        serviceRating = defaultRating
        priceRating = defaultRating
        menuRating = defaultRating
        comment = ""
        similarRestaurants = []
        showDuplicateWarning = false
        googleSuggestions = []
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
