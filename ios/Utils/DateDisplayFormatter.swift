import Foundation

enum DateDisplayFormatter {
    private static let outputFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        return formatter
    }()

    private static let dateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter
    }()

    private static let isoParserWithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let isoParser: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func fromISO(_ value: String) -> String {
        if let date = parseISO(value) {
            return outputFormatter.string(from: date)
        }
        return value
    }

    static func reviewDate(fromISO value: String) -> String {
        guard let date = parseISO(value) else { return value }

        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Oggi"
        }
        if calendar.isDateInYesterday(date) {
            return "Ieri"
        }
        if let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: Date()), calendar.isDate(date, inSameDayAs: twoDaysAgo) {
            return "L'altro ieri"
        }

        return dateOnlyFormatter.string(from: date)
    }

    private static func parseISO(_ value: String) -> Date? {
        isoParserWithFractional.date(from: value) ?? isoParser.date(from: value)
    }
}
