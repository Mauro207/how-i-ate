import Foundation

enum RestaurantURLValidator {
    static func validationMessage(for value: String, kind: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            return "URL \(kind) non valido"
        }
        return nil
    }

    static func googleMapsValidationMessage(for value: String) -> String? {
        guard validationMessage(for: value, kind: "Google Maps") == nil else {
            return "Inserisci un link Google Maps valido."
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let host = URL(string: trimmed)?.host?.lowercased() else { return nil }
        let isGoogleMapsHost = host.contains("google.") || host == "goo.gl" || host == "maps.app.goo.gl"
        guard isGoogleMapsHost else {
            return "Il link Google Maps deve provenire da Google Maps."
        }

        return nil
    }

    static func instagramValidationMessage(for value: String) -> String? {
        guard validationMessage(for: value, kind: "Instagram") == nil else {
            return "Inserisci un link Instagram valido."
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let host = URL(string: trimmed)?.host?.lowercased() else { return nil }
        guard host == "instagram.com" || host == "www.instagram.com" else {
            return "Il link Instagram deve provenire da instagram.com."
        }

        return nil
    }
}
