import SwiftUI

struct MyRatingsView: View {
    @EnvironmentObject private var session: SessionManager
    @StateObject var viewModel: MyRatingsViewModel
    let restaurantService: RestaurantService
    let reviewService: ReviewService
    let disableAutoLoad: Bool
    let targetUserId: String?
    let targetUserDisplayName: String?
    let embedInNavigationStack: Bool

    private var resolvedUserId: String? {
        targetUserId ?? session.currentUser?.id
    }

    private var isShowingCurrentUserRatings: Bool {
        if let targetUserId {
            return targetUserId == session.currentUser?.id
        }
        return true
    }

    private var navigationTitleText: String {
        if isShowingCurrentUserRatings {
            return "I tuoi voti"
        }
        let displayName = targetUserDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let displayName, !displayName.isEmpty {
            return "Classifica utente"
        }
        return "Voti utente"
    }

    private var reviewsTitleText: String {
        let displayName = (targetUserDisplayName ?? session.currentUser?.displayName ?? session.currentUser?.username)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let displayName, !displayName.isEmpty {
            return isShowingCurrentUserRatings ? "La tua classifica" : "Classifica di \(displayName)"
        }

        return isShowingCurrentUserRatings ? "La tua classifica" : "Classifica utente"
    }

    init(
        viewModel: MyRatingsViewModel,
        restaurantService: RestaurantService,
        reviewService: ReviewService,
        disableAutoLoad: Bool = false,
        targetUserId: String? = nil,
        targetUserDisplayName: String? = nil,
        embedInNavigationStack: Bool = true
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.restaurantService = restaurantService
        self.reviewService = reviewService
        self.disableAutoLoad = disableAutoLoad
        self.targetUserId = targetUserId
        self.targetUserDisplayName = targetUserDisplayName
        self.embedInNavigationStack = embedInNavigationStack
    }

    var body: some View {
        Group {
            if embedInNavigationStack {
                NavigationStack {
                    contentContainer
                }
            } else {
                contentContainer
            }
        }
    }

    private var contentContainer: some View {
        ScrollView {
            VStack(spacing: 16) {
                content
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(ratingsBackground)
        .navigationTitle(navigationTitleText)
        .task {
            guard !disableAutoLoad else { return }
            await viewModel.load(userId: resolvedUserId)
        }
        .refreshable {
            guard !disableAutoLoad else { return }
            await viewModel.load(userId: resolvedUserId)
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            loadingCard
        } else if let error = viewModel.errorMessage {
            stateCard(title: "Errore", systemImage: "exclamationmark.triangle", message: error)
        } else if viewModel.items.isEmpty {
            stateCard(
                title: "Nessun voto",
                systemImage: "chart.bar",
                message: viewModel.hasActiveCuisineFilters
                    ? "Non hai recensioni per le categorie selezionate"
                    : "Non hai ancora lasciato recensioni"
            )
        } else {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(reviewsTitleText)
                            .font(.title3.weight(.bold))
                        Text("\(viewModel.items.count) luoghi valutati")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)

                    if !viewModel.availableCuisines.isEmpty {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.toggleFilters()
                            }
                        } label: {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(viewModel.showFilters ? Color.indigo : Color.secondary)
                                .frame(width: 38, height: 38)
                                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(viewModel.showFilters ? "Nascondi filtri" : "Mostra filtri")
                        .modifier(FilterToggleButtonStyle(isActive: viewModel.showFilters))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if viewModel.showFilters, !viewModel.availableCuisines.isEmpty {
                    filterPanel
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                VStack(spacing: 10) {
                    ForEach(Array(viewModel.items.enumerated()), id: \.offset) { index, item in
                        NavigationLink {
                            RestaurantDetailView(
                                viewModel: RestaurantDetailViewModel(
                                    restaurantId: item.restaurantId,
                                    restaurantService: restaurantService,
                                    reviewService: reviewService,
                                    currentUserId: session.currentUser?.id
                                )
                            )
                        } label: {
                            MyRatingRowView(index: index, item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .ratingsGlassCard()
        }
    }

    private var filterPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text("Filtra per categoria")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                if !viewModel.hasActiveCuisineFilters {
                    Text("(tutte)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            FlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(viewModel.availableCuisines, id: \.self) { cuisine in
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            viewModel.toggleCuisine(cuisine)
                        }
                    } label: {
                        Text(cuisine)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(
                                viewModel.isCuisineIncluded(cuisine)
                                    ? Color.indigo
                                    : Color.primary.opacity(0.82)
                            )
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                    }
                    .buttonStyle(.plain)
                    .modifier(FilterChipStyle(isSelected: viewModel.isCuisineIncluded(cuisine)))
                }
            }
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.5), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        }
    }

    private var ratingsBackground: some View {
        LinearGradient(
            colors: [
                Color(uiColor: .systemGroupedBackground),
                Color.indigo.opacity(0.10),
                Color(uiColor: .systemBackground)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var loadingCard: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Caricamento voti...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .ratingsGlassCard()
    }

    private func stateCard(title: String, systemImage: String, message: String) -> some View {
        UnavailableStateView(title: title, systemImage: systemImage, message: message)
            .frame(height: 240)
            .frame(maxWidth: .infinity)
            .ratingsGlassCard()
    }
}

private struct RatingsGlassCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .padding(12)
                .glassEffect(.regular.tint(.indigo.opacity(0.06)), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        } else {
            content
                .padding(12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.primary.opacity(0.07), lineWidth: 1)
                }
        }
    }
}

private struct FilterToggleButtonStyle: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular.tint(isActive ? .indigo.opacity(0.16) : .clear), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        } else {
            content
                .background(
                    (isActive ? Color.indigo.opacity(0.12) : Color(uiColor: .secondarySystemBackground).opacity(0.75)),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                }
        }
    }
}

private struct FilterChipStyle: ViewModifier {
    let isSelected: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(
                    .regular.tint(isSelected ? .indigo.opacity(0.14) : .clear),
                    in: Capsule()
                )
                .overlay {
                    Capsule()
                        .stroke(
                            isSelected ? Color.indigo.opacity(0.40) : Color.primary.opacity(0.08),
                            lineWidth: isSelected ? 1.2 : 1
                        )
                }
        } else {
            content
                .background(
                    isSelected ? Color.indigo.opacity(0.12) : Color(uiColor: .secondarySystemBackground).opacity(0.9),
                    in: Capsule()
                )
                .overlay {
                    Capsule()
                        .stroke(
                            isSelected ? Color.indigo.opacity(0.40) : Color.primary.opacity(0.08),
                            lineWidth: isSelected ? 1.2 : 1
                        )
                }
        }
    }
}

private struct FlowLayout: Layout {
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat

    init(horizontalSpacing: CGFloat = 8, verticalSpacing: CGFloat = 8) {
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentLineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX > 0, currentX + size.width > maxWidth {
                totalHeight += currentLineHeight + verticalSpacing
                currentX = 0
                currentLineHeight = 0
            }

            currentX += size.width + horizontalSpacing
            currentLineHeight = max(currentLineHeight, size.height)
        }

        totalHeight += currentLineHeight
        return CGSize(width: maxWidth.isFinite ? maxWidth : currentX, height: totalHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var currentLineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX > bounds.minX, currentX + size.width > bounds.maxX {
                currentX = bounds.minX
                currentY += currentLineHeight + verticalSpacing
                currentLineHeight = 0
            }

            subview.place(
                at: CGPoint(x: currentX, y: currentY),
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )

            currentX += size.width + horizontalSpacing
            currentLineHeight = max(currentLineHeight, size.height)
        }
    }
}

private extension View {
    func ratingsGlassCard() -> some View {
        modifier(RatingsGlassCardModifier())
    }
}
