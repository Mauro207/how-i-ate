import SwiftUI

struct AdminPanelView: View {
    let client: APIClient

    var body: some View {
        NavigationStack {
            List {
                NavigationLink("Gestione suggerimenti") {
                    AdminSuggestionsView(
                        viewModel: AdminSuggestionsViewModel(service: SuggestionService(client: client))
                    )
                }

                NavigationLink("Gestione ristoranti") {
                    AdminRestaurantsView(
                        viewModel: AdminRestaurantsViewModel(service: RestaurantService(client: client))
                    )
                }
            }
            .navigationTitle("Admin")
        }
    }
}
