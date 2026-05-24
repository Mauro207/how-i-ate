import SwiftUI

#if DEBUG
private enum AddSuggestionPreviewFactory {
    static func make() -> some View {
        let client = APIClient(baseURL: URL(string: "https://example.com/api")!)
        return AddSuggestionTabView(
            service: SuggestionService(client: client),
            restaurantService: RestaurantService(client: client),
            reviewService: ReviewService(client: client)
        )
    }
}

@available(iOS 17.0, *)
#Preview("Add Suggestion") {
    AddSuggestionPreviewFactory.make()
}
#endif
