import Foundation

@MainActor
final class AdminSuggestionsViewModel: ObservableObject {
    @Published var suggestions: [Suggestion] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service: SuggestionService

    init(service: SuggestionService) {
        self.service = service
        suggestions = service.cachedSuggestions() ?? []
    }

    func load(forceRefresh: Bool = false) async {
        if !forceRefresh, suggestions.isEmpty, let cached = service.cachedSuggestions() {
            suggestions = cached
        }

        let shouldShowBlockingLoader = suggestions.isEmpty
        if shouldShowBlockingLoader {
            isLoading = true
        }
        defer { isLoading = false }

        do {
            suggestions = try await service.getSuggestions(forceRefresh: forceRefresh)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func approve(id: String) async {
        do {
            _ = try await service.approveSuggestion(id: id)
            suggestions.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reject(id: String) async {
        do {
            try await service.rejectSuggestion(id: id)
            suggestions.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
