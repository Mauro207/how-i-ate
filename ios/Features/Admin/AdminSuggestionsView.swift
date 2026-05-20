import SwiftUI

struct AdminSuggestionsView: View {
    @StateObject var viewModel: AdminSuggestionsViewModel
    @State private var approvingSuggestion: Suggestion?
    @State private var rejectingSuggestion: Suggestion?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Caricamento suggerimenti...")
                } else if let error = viewModel.errorMessage, viewModel.suggestions.isEmpty {
                    UnavailableStateView(title: "Errore", systemImage: "exclamationmark.triangle", message: error)
                } else {
                    List(viewModel.suggestions) { suggestion in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(suggestion.name)
                                .font(.headline)
                            if let cuisine = suggestion.cuisine, !cuisine.isEmpty {
                                Text(cuisine)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            if let address = suggestion.address, !address.isEmpty {
                                Text(address)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button("Approva") {
                                approvingSuggestion = suggestion
                            }
                            .tint(.green)

                            Button("Rifiuta", role: .destructive) {
                                rejectingSuggestion = suggestion
                            }
                        }
                    }
                }
            }
            .navigationTitle("Suggerimenti")
            .task { await viewModel.load() }
            .refreshable { await viewModel.load() }
        }
        .confirmationDialog(
            "Confermi approvazione suggerimento?",
            isPresented: Binding(
                get: { approvingSuggestion != nil },
                set: { if !$0 { approvingSuggestion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Approva", role: .none) {
                if let suggestion = approvingSuggestion {
                    Task {
                        await viewModel.approve(id: suggestion.id)
                        approvingSuggestion = nil
                    }
                }
            }
            Button("Annulla", role: .cancel) {
                approvingSuggestion = nil
            }
        }
        .confirmationDialog(
            "Confermi rifiuto suggerimento?",
            isPresented: Binding(
                get: { rejectingSuggestion != nil },
                set: { if !$0 { rejectingSuggestion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Rifiuta", role: .destructive) {
                if let suggestion = rejectingSuggestion {
                    Task {
                        await viewModel.reject(id: suggestion.id)
                        rejectingSuggestion = nil
                    }
                }
            }
            Button("Annulla", role: .cancel) {
                rejectingSuggestion = nil
            }
        }
    }
}
