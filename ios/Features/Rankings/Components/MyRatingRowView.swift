import SwiftUI

struct MyRatingRowView: View {
    let index: Int
    let item: UserRankingItem

    var body: some View {
        HStack(spacing: 12) {
            Text("\(index + 1)")
                .font(index < 3 ? .headline : .subheadline.weight(.bold))
                .foregroundStyle(index < 3 ? .white : .secondary)
                .frame(width: 36, height: 36)
                .background(positionColor(for: index), in: Circle())

            VStack(alignment: .leading, spacing: 5) {
                Text(item.restaurantName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Label("\(item.averageRating, specifier: "%.2f")", systemImage: "star.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.indigo)

                    Text("Voto medio")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)

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

    private func positionColor(for index: Int) -> Color {
        switch index {
        case 0: return Color(red: 0.93, green: 0.76, blue: 0.26)
        case 1: return Color(red: 0.67, green: 0.70, blue: 0.75)
        case 2: return Color(red: 0.74, green: 0.48, blue: 0.29)
        default: return Color(.secondarySystemBackground)
        }
    }
}
