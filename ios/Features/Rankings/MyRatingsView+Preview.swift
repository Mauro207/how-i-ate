import SwiftUI

#if DEBUG
private enum MyRatingsPreviewFactory {
    static func sampleItems() -> [UserRankingItem] {
        [
            UserRankingItem(
                restaurantId: "r1",
                restaurantName: "Trattoria del Porto",
                cuisine: "Ristorante",
                address: "Centro",
                averageRating: 9.25,
                serviceRating: 9,
                priceRating: 9.5,
                menuRating: 9.25,
                comment: "Ottimo",
                createdAt: nil,
                reviewCount: 42
            ),
            UserRankingItem(
                restaurantId: "r2",
                restaurantName: "Pizzeria Vesuvio",
                cuisine: "Pizzeria",
                address: "Nord",
                averageRating: 8.75,
                serviceRating: 8.5,
                priceRating: 9,
                menuRating: 8.75,
                comment: "Molto buona",
                createdAt: nil,
                reviewCount: 31
            ),
            UserRankingItem(
                restaurantId: "r3",
                restaurantName: "Sushi Hana",
                cuisine: "Sushi",
                address: "Sud",
                averageRating: 8.5,
                serviceRating: 8.5,
                priceRating: 8.5,
                menuRating: 8.5,
                comment: "Consigliato",
                createdAt: nil,
                reviewCount: 19
            ),
            UserRankingItem(
                restaurantId: "r4",
                restaurantName: "Bar Centrale",
                cuisine: "Bar",
                address: "Piazza",
                averageRating: 7.9,
                serviceRating: 8,
                priceRating: 7.5,
                menuRating: 8.25,
                comment: "Ok",
                createdAt: nil,
                reviewCount: 11
            )
        ]
    }

    static func makeScreen() -> some View {
        let client = APIClient(baseURL: URL(string: "https://example.com/api")!)
        let viewModel = MyRatingsViewModel(service: RankingService(client: client))
        viewModel.items = sampleItems()

        let session = SessionManager()
        session.currentUser = User(id: "u1", username: "preview", displayName: "Preview", email: "", role: "user")
        session.isAuthenticated = true

        return MyRatingsView(
            viewModel: viewModel,
            restaurantService: RestaurantService(client: client),
            reviewService: ReviewService(client: client),
            disableAutoLoad: true
        )
        .environmentObject(session)
    }
}

@available(iOS 17.0, *)
#Preview("My Ratings Screen") {
    MyRatingsPreviewFactory.makeScreen()
}

@available(iOS 17.0, *)
#Preview("My Ratings Row Playground") {
    @Previewable @State var rowIndex = 0
    let maxIndex = max(0, MyRatingsPreviewFactory.sampleItems().count - 1)

    VStack(alignment: .leading, spacing: 12) {
        Stepper("Posizione: \(rowIndex + 1)", value: $rowIndex, in: 0 ... maxIndex)
        MyRatingRowView(index: rowIndex, item: MyRatingsPreviewFactory.sampleItems()[rowIndex])
    }
    .padding()
}
#endif
