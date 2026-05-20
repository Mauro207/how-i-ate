import Foundation

enum RankingCalculator {
    static func toRankingAverage(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return (value * 4).rounded() / 4
    }

    static func sort(_ lhs: RankingItem, _ rhs: RankingItem) -> Bool {
        let leftAverage = toRankingAverage(lhs.averageRating)
        let rightAverage = toRankingAverage(rhs.averageRating)

        if leftAverage != rightAverage {
            return leftAverage > rightAverage
        }

        if lhs.reviewCount != rhs.reviewCount {
            return lhs.reviewCount > rhs.reviewCount
        }

        return lhs.restaurantName.localizedCaseInsensitiveCompare(rhs.restaurantName) == .orderedAscending
    }
}
