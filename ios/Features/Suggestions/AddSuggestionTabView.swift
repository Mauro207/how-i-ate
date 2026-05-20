import SwiftUI

struct AddSuggestionTabView: View {
    let service: SuggestionService

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
    @State private var isSubmitting = false
    @State private var message: String?

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

                if let message {
                    Section {
                        Text(message)
                            .foregroundStyle(message.lowercased().contains("successo") ? .green : .red)
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
            .navigationTitle("Suggerisci luogo")
        }
    }

    private func submitSuggestion() async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedComment = comment.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmedName.count >= 2 else {
            message = "Inserisci un nome luogo valido"
            return
        }

        guard trimmedComment.count >= 5 else {
            message = "Il commento deve avere almeno 5 caratteri"
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
            message = "Suggerimento inviato con successo"
            clearForm()
        } catch {
            message = error.localizedDescription
        }
    }

    private func clearForm() {
        name = ""
        description = ""
        address = ""
        cuisine = ""
        mapsUrl = ""
        instagramUrl = ""
        serviceRating = 7.0
        priceRating = 7.0
        menuRating = 7.0
        comment = ""
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
