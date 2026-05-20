import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case forbidden
    case notFound
    case server(status: Int, message: String)
    case decoding(Error)
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL non valido"
        case .invalidResponse:
            return "Risposta server non valida"
        case .unauthorized:
            return "Sessione non valida. Effettua di nuovo il login."
        case .forbidden:
            return "Non hai i permessi per questa azione"
        case .notFound:
            return "Risorsa non trovata"
        case let .server(_, message):
            return message
        case let .decoding(error):
            return "Errore decodifica risposta: \(error.localizedDescription)"
        case let .transport(error):
            return "Errore di rete: \(error.localizedDescription)"
        }
    }
}
