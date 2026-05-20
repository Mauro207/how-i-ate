import SwiftUI

struct AdminAddPlaceView: View {
    let restaurantService: RestaurantService
    let suggestionService: SuggestionService

    @State private var name = ""
    @State private var description = ""
    @State private var address = ""
    @State private var cuisine = ""
    @State private var coverImageUrl = ""
    @State private var googleMapsUrl = ""
    @State private var instagramUrl = ""

    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var isSubmitting = false

    @State private var checkingDuplicate = false
    @State private var similarRestaurants: [Restaurant] = []
    @State private var showDuplicateWarning = false

    @State private var googleSuggestions: [GooglePlaceSuggestion] = []
    @State private var loadingGooglePlaces = false

    @State private var pendingSuggestionsCount = 0
    @State private var openSuggestions = false

    private let cuisineOptions = ["Pizzeria", "Ristorante", "Pub", "Paninoteca", "Bar", "Braceria", "Enoteca", "Sushi", "Pasticceria", "Gelateria"]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        openSuggestions = true
                    } label: {
                        HStack {
                            Label("Valuta suggerimenti", systemImage: "tray.full")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            if pendingSuggestionsCount > 0 {
                                Text("\(pendingSuggestionsCount)")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(.red, in: Capsule())
                            }
                        }
                    }
                }

                Section("Informazioni luogo") {
                    TextField("Nome luogo", text: $name)
                        .onSubmit {
                            Task { await checkForDuplicatesAndSuggestions() }
                        }

                    if checkingDuplicate {
                        ProgressView("Verifico se il luogo esiste gia...")
                            .font(.caption)
                    }

                    if showDuplicateWarning {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "info.circle.fill")
                                    .foregroundStyle(.indigo)
                                Text("Possibili luoghi gia presenti")
                                    .font(.subheadline.weight(.semibold))
                            }
                            Text("Abbiamo trovato \(similarRestaurants.count) risultato/i simile/i. Verifica prima di creare un duplicato.")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            ForEach(similarRestaurants.prefix(5)) { restaurant in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(restaurant.name)
                                        .font(.footnote.weight(.semibold))
                                    Text([restaurant.cuisine, restaurant.address]
                                        .compactMap { $0?.nilIfEmpty }
                                        .joined(separator: " · "))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 2)
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
                    TextField("Google Maps URL", text: $googleMapsUrl)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Profilo Instagram", text: $instagramUrl)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Immagine copertina URL", text: $coverImageUrl)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Descrizione", text: $description, axis: .vertical)
                }

                if let successMessage {
                    Section {
                        Text(successMessage)
                            .foregroundStyle(.green)
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        Task { await submitRestaurant() }
                    } label: {
                        if isSubmitting {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Crea luogo")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(isSubmitting)
                }
            }
            .navigationTitle("Aggiungi luogo")
            .task {
                await refreshPendingSuggestionsCount()
            }
            .onChange(of: name) { newValue in
                if newValue.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 {
                    similarRestaurants = []
                    showDuplicateWarning = false
                    googleSuggestions = []
                }
            }
            .navigationDestination(isPresented: $openSuggestions) {
                AdminSuggestionsView(
                    viewModel: AdminSuggestionsViewModel(service: suggestionService)
                )
            }
        }
    }

    private func submitRestaurant() async {
        successMessage = nil
        errorMessage = nil

        let trimmedName = name.trimmed
        guard !trimmedName.isEmpty else {
            errorMessage = "Il nome del luogo e obbligatorio."
            return
        }

        if let validation = validateURLField(googleMapsUrl, kind: "Google Maps") {
            errorMessage = validation
            return
        }

        if let validation = validateURLField(instagramUrl, kind: "Instagram") {
            errorMessage = validation
            return
        }

        if let validation = validateURLField(coverImageUrl, kind: "Copertina") {
            errorMessage = validation
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            _ = try await restaurantService.createRestaurant(
                payload: RestaurantMutationPayload(
                    name: trimmedName,
                    description: description.nilIfEmpty,
                    address: address.nilIfEmpty,
                    cuisine: cuisine.nilIfEmpty,
                    coverImageUrl: coverImageUrl.nilIfEmpty,
                    googleMapsUrl: googleMapsUrl.nilIfEmpty,
                    instagramUrl: instagramUrl.nilIfEmpty
                )
            )
            successMessage = "Luogo creato con successo"
            clearForm()
            await refreshPendingSuggestionsCount()
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
            // On iOS, if backend rejects this endpoint we silently hide suggestions.
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
                googleMapsUrl = place.mapsUrl.trimmed
            }
            googleSuggestions = []
        } catch {
            errorMessage = "Impossibile recuperare i dettagli del luogo da Google Maps."
        }
    }

    private func refreshPendingSuggestionsCount() async {
        do {
            let suggestions = try await suggestionService.getSuggestions()
            pendingSuggestionsCount = suggestions.filter { ($0.status ?? "") == "pending" }.count
        } catch {
            pendingSuggestionsCount = 0
        }
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
        coverImageUrl = ""
        googleMapsUrl = ""
        instagramUrl = ""
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
