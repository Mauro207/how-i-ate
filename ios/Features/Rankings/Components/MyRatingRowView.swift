import SwiftUI

struct MyRatingRowView: View {
    let index: Int
    let item: UserRankingItem

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
                    .background(positionColor(for: index), in: Circle())

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

    private func positionColor(for index: Int) -> Color {
        switch index {
        case 0: return Color(red: 0.93, green: 0.76, blue: 0.26)
        case 1: return Color(red: 0.67, green: 0.70, blue: 0.75)
        case 2: return Color(red: 0.74, green: 0.48, blue: 0.29)
        default: return Color(.secondarySystemBackground)
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
