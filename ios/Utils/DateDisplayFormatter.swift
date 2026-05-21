import Foundation

enum DateDisplayFormatter {
    private static let outputFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
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
        if let date = isoParserWithFractional.date(from: value) ?? isoParser.date(from: value) {
            return outputFormatter.string(from: date)
        }
        return value
    }
}