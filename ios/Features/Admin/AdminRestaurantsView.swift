import SwiftUI

struct AdminRestaurantsView: View {
    @StateObject var viewModel: AdminRestaurantsViewModel
    @State private var creatingRestaurant = false
    @State private var editingRestaurant: Restaurant?
    @State private var deletingRestaurant: Restaurant?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Caricamento ristoranti...")
                } else if let error = viewModel.errorMessage, viewModel.restaurants.isEmpty {
                    UnavailableStateView(title: "Errore", systemImage: "exclamationmark.triangle", message: error)
                } else {
                    List(viewModel.restaurants) { restaurant in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(restaurant.name)
                                .font(.headline)
                            if let cuisine = restaurant.cuisine, !cuisine.isEmpty {
                                Text(cuisine)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Modifica") {
                                editingRestaurant = restaurant
                            }
                            .tint(.blue)

                            Button("Elimina", role: .destructive) {
                                deletingRestaurant = restaurant
                            }
                        }
                    }
                }
            }
            .navigationTitle("Ristoranti Admin")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        creatingRestaurant = true
                    } label: {
                        Label("Nuovo", systemImage: "plus")
                    }
                }
            }
            .task { await viewModel.load() }
            .refreshable { await viewModel.load() }
        }
        .sheet(isPresented: $creatingRestaurant) {
            RestaurantEditorView(title: "Nuovo ristorante") { payload in
                await viewModel.create(payload: payload)
                if viewModel.errorMessage == nil {
                    creatingRestaurant = false
                }
            }
            .presentationDetents([.large])
        }
        .sheet(item: $editingRestaurant) { restaurant in
            RestaurantEditorView(restaurant: restaurant, title: "Modifica ristorante") { payload in
                await viewModel.update(id: restaurant.id, payload: payload)
                if viewModel.errorMessage == nil {
                    editingRestaurant = nil
                }
            }
            .presentationDetents([.large])
        }
        .confirmationDialog(
            "Confermi eliminazione ristorante?",
            isPresented: Binding(
                get: { deletingRestaurant != nil },
                set: { if !$0 { deletingRestaurant = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Elimina", role: .destructive) {
                if let restaurant = deletingRestaurant {
                    Task {
                        await viewModel.delete(id: restaurant.id)
                        deletingRestaurant = nil
                    }
                }
            }
            Button("Annulla", role: .cancel) {
                deletingRestaurant = nil
            }
        }
    }
}

private struct RestaurantEditorView: View {
    let title: String
    let onSubmit: (RestaurantMutationPayload) async -> Void

    @State private var name: String
    @State private var description: String
    @State private var address: String
    @State private var cuisine: String
    @State private var coverImageUrl: String
    @State private var googleMapsUrl: String
    @State private var instagramUrl: String

    init(restaurant: Restaurant? = nil, title: String, onSubmit: @escaping (RestaurantMutationPayload) async -> Void) {
        self.title = title
        self.onSubmit = onSubmit
        _name = State(initialValue: restaurant?.name ?? "")
        _description = State(initialValue: restaurant?.description ?? "")
        _address = State(initialValue: restaurant?.address ?? "")
        _cuisine = State(initialValue: restaurant?.cuisine ?? "")
        _coverImageUrl = State(initialValue: restaurant?.coverImageUrl ?? "")
        _googleMapsUrl = State(initialValue: restaurant?.googleMapsUrl ?? "")
        _instagramUrl = State(initialValue: restaurant?.instagramUrl ?? "")
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
                    Button("Salva") {
                        Task {
                            let payload = RestaurantMutationPayload(
                                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                                description: description.nilIfEmpty,
                                address: address.nilIfEmpty,
                                cuisine: cuisine.nilIfEmpty,
                                coverImageUrl: coverImageUrl.nilIfEmpty,
                                googleMapsUrl: googleMapsUrl.nilIfEmpty,
                                instagramUrl: instagramUrl.nilIfEmpty
                            )
                            await onSubmit(payload)
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle(title)
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
