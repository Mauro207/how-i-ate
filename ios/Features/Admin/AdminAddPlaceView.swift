import SwiftUI

struct AdminAddPlaceView: View {
    @EnvironmentObject private var session: SessionManager
    let restaurantService: RestaurantService
    let reviewService: ReviewService
    let suggestionService: SuggestionService
    let disableInitialLoad: Bool

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

    @FocusState private var isNameFieldFocused: Bool

    @State private var pendingSuggestionsCount = 0
    @State private var openSuggestions = false

    private let cuisineOptions = PlaceTypeOptions.all

    init(
        restaurantService: RestaurantService,
        reviewService: ReviewService,
        suggestionService: SuggestionService,
        disableInitialLoad: Bool = false
    ) {
        self.restaurantService = restaurantService
        self.reviewService = reviewService
        self.suggestionService = suggestionService
        self.disableInitialLoad = disableInitialLoad
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    suggestionsButton

                    adminGlassCard {
                        VStack(alignment: .leading, spacing: 18) {
                            sectionHeader(title: "Informazioni luogo", subtitle: "Crea un nuovo posto da recensire")

                            inputGroup(title: "Nome luogo", icon: "fork.knife") {
                                TextField("Nome luogo", text: $name)
                                    .focused($isNameFieldFocused)
                                    .submitLabel(.search)
                                    .onSubmit {
                                        Task { await checkForDuplicatesAndSuggestions() }
                                    }
                            }

                            duplicateAndGoogleState

                            Picker("Tipo di luogo", selection: $cuisine) {
                                Text("Seleziona tipo di luogo").tag("")
                                ForEach(cuisineOptions, id: \.self) { item in
                                    Text(item).tag(item)
                                }
                            }
                            .font(.subheadline)
                            .padding(.horizontal, 14)
                            .frame(height: 54)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(fieldBackgroundShape)

                            inputGroup(title: "Indirizzo", icon: "mappin.and.ellipse") {
                                TextField("Indirizzo", text: $address)
                                    .textContentType(.fullStreetAddress)
                            }

                            inputGroup(title: "Google Maps", icon: "map") {
                                TextField("Google Maps URL", text: $googleMapsUrl)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .keyboardType(.URL)
                            }

                            inputGroup(title: "Instagram", icon: "camera") {
                                TextField("Profilo Instagram", text: $instagramUrl)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .keyboardType(.URL)
                            }

                            inputGroup(title: "Copertina", icon: "photo") {
                                TextField("Immagine copertina URL", text: $coverImageUrl)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .keyboardType(.URL)
                            }

                            inputGroup(title: "Descrizione", icon: "text.alignleft", minHeight: 92) {
                                TextField("Descrizione", text: $description, axis: .vertical)
                                    .lineLimit(3 ... 5)
                            }
                        }
                    }

                    if let successMessage {
                        statusBanner(successMessage, systemImage: "checkmark.circle.fill", color: .green)
                    }

                    if let errorMessage {
                        statusBanner(errorMessage, systemImage: "exclamationmark.triangle.fill", color: .red)
                    }

                    createButton
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .background(adminBackground)
            .navigationTitle("Aggiungi luogo")
            .task {
                guard !disableInitialLoad else { return }
                await refreshPendingSuggestionsCount()
            }
            .onChange(of: name) { newValue in
                if newValue.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 {
                    similarRestaurants = []
                    showDuplicateWarning = false
                    googleSuggestions = []
                }
            }
            .onChange(of: isNameFieldFocused) { focused in
                guard !focused else { return }
                Task { await checkForDuplicatesAndSuggestions() }
            }
            .navigationDestination(isPresented: $openSuggestions) {
                AdminSuggestionsView(
                    viewModel: AdminSuggestionsViewModel(service: suggestionService)
                )
            }
        }
    }

    private var adminBackground: some View {
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

    private var fieldBackgroundShape: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.72))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.primary.opacity(0.07), lineWidth: 1)
            }
    }

    private var suggestionsButton: some View {
        Button {
            openSuggestions = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "tray.full")
                    .font(.headline)
                    .foregroundStyle(Color.indigo)
                    .frame(width: 40, height: 40)
                    .background(Color.indigo.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                Text("Valuta suggerimenti")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer()

                if pendingSuggestionsCount > 0 {
                    Text("\(pendingSuggestionsCount)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.red, in: Capsule())
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .adminGlassCard()
    }

    @ViewBuilder
    private var duplicateAndGoogleState: some View {
        if checkingDuplicate {
            inlineStatus("Verifico se il luogo esiste gia...", systemImage: "magnifyingglass", color: .indigo)
        }

        if showDuplicateWarning {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                        Text("Possibili luoghi gia presenti")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(.indigo)

                    Spacer(minLength: 0)

                    Button {
                        dismissDuplicateWarning()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .padding(6)
                            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Chiudi avviso duplicati")
                }

                Text("Abbiamo trovato \(similarRestaurants.count) risultato/i simile/i. Verifica prima di creare un duplicato.")
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
                            VStack(alignment: .leading, spacing: 3) {
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
                        .padding(10)
                        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }

        if !showDuplicateWarning, loadingGooglePlaces {
            inlineStatus("Cerco suggerimenti su Google Maps...", systemImage: "map", color: .indigo)
        }

        if !showDuplicateWarning, !googleSuggestions.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Suggerimenti Google Maps")
                    .font(.subheadline.weight(.semibold))

                ForEach(googleSuggestions) { suggestion in
                    Button {
                        Task { await selectGoogleSuggestion(suggestion) }
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(suggestion.mainText)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text(suggestion.secondaryText.isEmpty ? suggestion.description : suggestion.secondaryText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Color.indigo.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var createButton: some View {
        Button {
            Task { await submitRestaurant() }
        } label: {
            HStack(spacing: 8) {
                if isSubmitting {
                    ProgressView()
                        .tint(.white)
                }
                Text(isSubmitting ? "Creazione in corso..." : "Crea luogo")
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
        .modifier(AdminPrimaryGlassButtonModifier())
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title3.weight(.bold))
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func inputGroup<Content: View>(
        title: String,
        icon: String,
        minHeight: CGFloat = 54,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack {
                content()
            }
            .padding(.horizontal, 14)
            .frame(minHeight: minHeight)
            .background(fieldBackgroundShape)
        }
    }

    private func inlineStatus(_ text: String, systemImage: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
            Text(text)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(color)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statusBanner(_ text: String, systemImage: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.footnote.weight(.semibold))
            Text(text)
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(color)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .adminGlassCard()
    }

    @ViewBuilder
    private func adminGlassCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(14)
            .adminGlassCard()
    }

    private func submitRestaurant() async {
        successMessage = nil
        errorMessage = nil

        let trimmedName = name.trimmed
        guard !trimmedName.isEmpty else {
            errorMessage = "Il nome del luogo e obbligatorio."
            return
        }

        if let validation = RestaurantURLValidator.googleMapsValidationMessage(for: googleMapsUrl) {
            errorMessage = validation
            return
        }

        if let validation = RestaurantURLValidator.instagramValidationMessage(for: instagramUrl) {
            errorMessage = validation
            return
        }

        if let validation = RestaurantURLValidator.validationMessage(for: coverImageUrl, kind: "Copertina") {
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

    private func dismissDuplicateWarning() {
        showDuplicateWarning = false
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

private struct AdminGlassCardModifier: ViewModifier {
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

private struct AdminPrimaryGlassButtonModifier: ViewModifier {
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
    func adminGlassCard() -> some View {
        modifier(AdminGlassCardModifier())
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
