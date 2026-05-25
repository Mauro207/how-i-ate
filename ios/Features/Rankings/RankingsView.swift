import SwiftUI

struct RankingsView: View {
    @EnvironmentObject private var session: SessionManager
    @StateObject var viewModel: RankingsViewModel
    let restaurantService: RestaurantService
    let reviewService: ReviewService

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    content
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .background(rankingsBackground)
            .navigationTitle("Rankings")
            .task { await viewModel.loadGlobal() }
            .refreshable { await viewModel.loadGlobal(forceRefresh: true) }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            loadingCard
        } else if let error = viewModel.errorMessage {
            stateCard(title: "Errore", systemImage: "exclamationmark.triangle", message: error)
        } else if viewModel.rankings.isEmpty {
            stateCard(title: "Nessuna classifica", systemImage: "chart.bar", message: "Non ci sono ancora recensioni sufficienti")
        } else {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Classifica globale")
                        .font(.title3.weight(.bold))
                    Text("\(viewModel.rankings.count) luoghi ordinati per valutazione media")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 10) {
                    ForEach(Array(viewModel.rankings.enumerated()), id: \.offset) { index, item in
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
                            RankingRowCard(index: index, item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .rankingsGlassCard()
        }
    }

    private var rankingsBackground: some View {
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
            Text("Caricamento rankings...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .rankingsGlassCard()
    }

    private func stateCard(title: String, systemImage: String, message: String) -> some View {
        UnavailableStateView(title: title, systemImage: systemImage, message: message)
            .frame(height: 240)
            .frame(maxWidth: .infinity)
            .rankingsGlassCard()
    }
}

private struct RankingRowCard: View {
    let index: Int
    let item: RankingItem

    private var averageRatingText: String {
        String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), item.averageRating)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(spacing: 2) {
                Text("\(index + 1)")
                    .font(index < 3 ? .headline : .subheadline.weight(.bold))
                    .foregroundStyle(index < 3 ? .white : .secondary)
                    .frame(width: 38, height: 38)
                    .background(rankBadgeColor(for: index), in: Circle())

                Text("TOP")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(item.restaurantName)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let details = rankingDetailsText {
                    Text(details)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.caption.weight(.bold))
                    Text(averageRatingText)
                        .font(.title3.weight(.bold))
                }
                .foregroundStyle(Color.indigo)

                Text("\(item.reviewCount) recensioni")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Color.indigo.opacity(0.11), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.72), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        }
    }

    private var rankingDetailsText: String? {
        [item.cuisine, item.address]
            .compactMap { value in
                let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed?.isEmpty == false ? trimmed : nil
            }
            .joined(separator: " • ")
            .nilIfEmpty
    }
}

private struct RankingsGlassCardModifier: ViewModifier {
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

private extension View {
    func rankingsGlassCard() -> some View {
        modifier(RankingsGlassCardModifier())
    }
}

private func rankBadgeColor(for index: Int) -> Color {
    switch index {
    case 0: return Color(red: 0.93, green: 0.76, blue: 0.26)
    case 1: return Color(red: 0.67, green: 0.70, blue: 0.75)
    case 2: return Color(red: 0.74, green: 0.48, blue: 0.29)
    default: return Color(.secondarySystemBackground)
    }
}

private extension String {
    var nilIfEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
