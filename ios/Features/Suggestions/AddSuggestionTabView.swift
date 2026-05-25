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

    private let cuisineOptions = PlaceTypeOptions.all

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    headerCard

                    if success {
                        statusBanner(
                            "Suggerimento inviato con successo. La tua proposta sara revisionata dagli amministratori.",
                            systemImage: "checkmark.circle.fill",
                            color: .green
                        )
                    }

                    if let errorMessage {
                        statusBanner(errorMessage, systemImage: "exclamationmark.triangle.fill", color: .red)
                    }

                    if !success {
                        placeInfoCard
                        reviewCard
                        submitButton
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .background(suggestionBackground)
            .navigationTitle("Suggerisci")
            .onChange(of: name) { newValue in
                success = false
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

    private var suggestionBackground: some View {
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

    private var headerCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.indigo)
                .frame(width: 46, height: 46)
                .background(Color.indigo.opacity(0.12), in: RoundedRectangle(cornerRadius: 15, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text("Suggerisci un luogo")
                    .font(.title3.weight(.bold))
                Text("Proponi un nuovo posto e aggiungi subito la tua recensione.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .suggestionGlassCard()
    }

    private var placeInfoCard: some View {
        suggestionGlassCard {
            VStack(alignment: .leading, spacing: 18) {
                sectionHeader(title: "Informazioni luogo", subtitle: "Aiuta gli admin a riconoscere il posto corretto")

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
                    TextField("Google Maps URL", text: $mapsUrl)
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

                inputGroup(title: "Descrizione", icon: "text.alignleft", minHeight: 92) {
                    TextField("Descrizione", text: $description, axis: .vertical)
                        .lineLimit(3 ... 5)
                }
            }
        }
    }

    private var reviewCard: some View {
        suggestionGlassCard {
            VStack(alignment: .leading, spacing: 18) {
                sectionHeader(title: "La tua recensione", subtitle: "Dai una prima valutazione al luogo che stai suggerendo")

                ratingSlider(title: "Servizio", value: $serviceRating, color: .blue)
                ratingSlider(title: "Prezzo", value: $priceRating, color: .green)
                ratingSlider(title: "Menu", value: $menuRating, color: .purple)

                VStack(alignment: .leading, spacing: 8) {
                    Label("Commento", systemImage: "text.bubble")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)

                    TextEditor(text: $comment)
                        .frame(minHeight: 126)
                        .scrollContentBackground(.hidden)
                        .padding(12)
                        .background(fieldBackgroundShape)
                }

                if !comment.trimmed.isEmpty, comment.trimmed.count < 5 {
                    inlineStatus("Il commento deve avere almeno 5 caratteri", systemImage: "exclamationmark.circle.fill", color: .red)
                }
            }
        }
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

                Text("Abbiamo trovato \(similarRestaurants.count) luogo/i simile/i gia presente/i. Verifica prima di inviare un duplicato.")
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
                                    .lineLimit(2)
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

    private var submitButton: some View {
        Button {
            Task { await submitSuggestion() }
        } label: {
            HStack(spacing: 8) {
                if isSubmitting {
                    ProgressView()
                        .tint(.white)
                }
                Text(isSubmitting ? "Invio in corso..." : "Invia suggerimento")
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
        .modifier(SuggestionPrimaryGlassButtonModifier())
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

    private func ratingSlider(title: String, value: Binding<Double>, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(formatRating(value.wrappedValue)) / \(maxRating, specifier: "%.1f")")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(color.opacity(0.12), in: Capsule())
            }

            Slider(value: value, in: minRating ... maxRating, step: ratingStep)
                .tint(color)
        }
    }

    private func inlineStatus(_ text: String, systemImage: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
            Text(text)
                .font(.caption.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
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
            Spacer(minLength: 0)
        }
        .foregroundStyle(color)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .suggestionGlassCard()
    }

    @ViewBuilder
    private func suggestionGlassCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(14)
            .suggestionGlassCard()
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

    private func dismissDuplicateWarning() {
        showDuplicateWarning = false
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

private struct SuggestionGlassCardModifier: ViewModifier {
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

private struct SuggestionPrimaryGlassButtonModifier: ViewModifier {
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
    func suggestionGlassCard() -> some View {
        modifier(SuggestionGlassCardModifier())
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
