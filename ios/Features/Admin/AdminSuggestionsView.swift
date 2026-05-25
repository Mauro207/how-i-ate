import SwiftUI

struct AdminSuggestionsView: View {
    @StateObject var viewModel: AdminSuggestionsViewModel
    @State private var approvingSuggestion: Suggestion?
    @State private var rejectingSuggestion: Suggestion?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    headerCard

                    if viewModel.isLoading && viewModel.suggestions.isEmpty {
                        loadingState
                    } else if let error = viewModel.errorMessage, viewModel.suggestions.isEmpty {
                        unavailableCard(
                            title: "Errore",
                            message: error,
                            systemImage: "exclamationmark.triangle.fill",
                            color: .red
                        )
                    } else if viewModel.suggestions.isEmpty {
                        unavailableCard(
                            title: "Nessun suggerimento",
                            message: "Non ci sono luoghi da revisionare al momento.",
                            systemImage: "checkmark.seal.fill",
                            color: .green
                        )
                    } else {
                        if let error = viewModel.errorMessage {
                            statusBanner(error, systemImage: "exclamationmark.triangle.fill", color: .red)
                        }

                        LazyVStack(spacing: 14) {
                            ForEach(viewModel.suggestions) { suggestion in
                                suggestionCard(suggestion)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .background(adminSuggestionsBackground)
            .navigationTitle("Suggerimenti")
            .task { await viewModel.load() }
            .refreshable { await viewModel.load(forceRefresh: true) }
        }
        .confirmationDialog(
            "Confermi approvazione suggerimento?",
            isPresented: Binding(
                get: { approvingSuggestion != nil },
                set: { if !$0 { approvingSuggestion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Approva") {
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

    private var adminSuggestionsBackground: some View {
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

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "tray.full")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.indigo)
                    .frame(width: 44, height: 44)
                    .background(Color.indigo.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Suggerimenti in attesa")
                        .font(.headline)
                    Text("Revisiona i luoghi proposti dagli utenti")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Text("\(viewModel.suggestions.count)")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.indigo)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.indigo.opacity(0.12), in: Capsule())
            }

            if viewModel.isLoading && !viewModel.suggestions.isEmpty {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Aggiorno elenco...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .adminSuggestionsGlassCard()
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
            Text("Caricamento suggerimenti...")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .adminSuggestionsGlassCard()
    }

    private func suggestionCard(_ suggestion: Suggestion) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(suggestion.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(2)

                        Spacer(minLength: 0)

                        statusPill(suggestion.status)
                    }

                    suggestionMeta(suggestion)
                }
            }

            if let description = suggestion.description?.trimmed, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            linkChips(for: suggestion)

            Divider()
                .overlay(Color.primary.opacity(0.08))

            HStack(spacing: 10) {
                Button {
                    rejectingSuggestion = suggestion
                } label: {
                    Label("Rifiuta", systemImage: "xmark")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
                .background(Color.red.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                Button {
                    approvingSuggestion = suggestion
                } label: {
                    Label("Approva", systemImage: "checkmark")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .adminSuggestionsPrimaryButton()
            }
        }
        .padding(16)
        .adminSuggestionsGlassCard()
    }

    private func suggestionMeta(_ suggestion: Suggestion) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            if let cuisine = suggestion.cuisine?.trimmed, !cuisine.isEmpty {
                metaRow("fork.knife", cuisine)
            }

            if let address = suggestion.address?.trimmed, !address.isEmpty {
                metaRow("mappin.and.ellipse", address)
            }

            if let suggestedBy = suggestion.suggestedBy {
                metaRow("person.crop.circle", suggestedBy.displayLabel)
            }

            if let createdAt = suggestion.createdAt?.trimmed, !createdAt.isEmpty {
                metaRow("calendar", DateDisplayFormatter.fromISO(createdAt))
            }
        }
    }

    @ViewBuilder
    private func linkChips(for suggestion: Suggestion) -> some View {
        let links = suggestionLinks(for: suggestion)
        if !links.isEmpty {
            HStack(spacing: 10) {
                ForEach(links, id: \.title) { link in
                    Link(destination: link.url) {
                        Label(link.title, systemImage: link.systemImage)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.indigo)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.indigo.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            }
        }
    }

    private func suggestionLinks(for suggestion: Suggestion) -> [(title: String, systemImage: String, url: URL)] {
        var links: [(String, String, URL)] = []
        if let maps = suggestion.googleMapsUrl?.trimmed, let url = URL(string: maps), !maps.isEmpty {
            links.append(("Maps", "map", url))
        }
        if let instagram = suggestion.instagramUrl?.trimmed, let url = URL(string: instagram), !instagram.isEmpty {
            links.append(("Instagram", "camera", url))
        }
        return links
    }

    private func metaRow(_ systemImage: String, _ text: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.indigo)
                .frame(width: 16)
            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }

    private func statusPill(_ status: String?) -> some View {
        Text(statusLabel(status))
            .font(.caption.weight(.bold))
            .foregroundStyle(statusColor(status))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(statusColor(status).opacity(0.12), in: Capsule())
    }

    private func statusLabel(_ status: String?) -> String {
        switch status?.lowercased() {
        case "approved":
            return "Approvato"
        case "rejected":
            return "Rifiutato"
        default:
            return "In attesa"
        }
    }

    private func statusColor(_ status: String?) -> Color {
        switch status?.lowercased() {
        case "approved":
            return .green
        case "rejected":
            return .red
        default:
            return .orange
        }
    }

    private func statusBanner(_ message: String, systemImage: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(color)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func unavailableCard(title: String, message: String, systemImage: String, color: Color) -> some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title2.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 48, height: 48)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .padding(.horizontal, 18)
        .adminSuggestionsGlassCard()
    }
}

private struct AdminSuggestionsGlassCardModifier: ViewModifier {
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

private struct AdminSuggestionsPrimaryButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular.tint(.green).interactive(), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        } else {
            content
                .background(Color.green, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

private extension View {
    func adminSuggestionsGlassCard() -> some View {
        modifier(AdminSuggestionsGlassCardModifier())
    }

    func adminSuggestionsPrimaryButton() -> some View {
        modifier(AdminSuggestionsPrimaryButtonModifier())
    }
}

private extension ReviewUser {
    var displayLabel: String {
        if let displayName = displayName?.trimmed, !displayName.isEmpty {
            return displayName
        }
        return username
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
