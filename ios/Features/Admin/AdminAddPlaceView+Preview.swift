import SwiftUI

#if DEBUG
private enum AdminAddPlacePreviewFactory {
    static func make() -> some View {
        let client = APIClient(baseURL: URL(string: "https://example.com/api")!)
        return AdminAddPlaceView(
            restaurantService: RestaurantService(client: client),
            suggestionService: SuggestionService(client: client),
            disableInitialLoad: true
        )
    }
}

@available(iOS 17.0, *)
#Preview("Admin Add Place") {
    AdminAddPlacePreviewFactory.make()
}
#endif
