import SwiftUI

struct UpdatesView: View {
    private let entries: [UpdateEntry] = [
        .init(title: "v1.2.1 - Suggerimenti da Google Maps e miglioramenti vari"),
        .init(title: "v1.2 - Riassunti con Gemini e nuova interfaccia"),
        .init(title: "v1.1.3 - Controllo duplicati e fix recensioni"),
        .init(title: "v1.1.2 - Modifica un luogo"),
        .init(title: "v1.1.1 - Copertine e aggiornamenti minori"),
        .init(title: "v1.1.0 - Aggiornamento design webapp"),
        .init(title: "v1.0.3 - Disponibile la webapp"),
        .init(title: "v1.0.2 - Notifiche e aggiornamento recensioni"),
        .init(title: "v1.0.1 - Luoghi suggeriti e miglioramenti UI"),
        .init(title: "v1.0.0 - Prima release")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                headerCard

                VStack(spacing: 10) {
                    ForEach(entries) { entry in
                        HStack(spacing: 10) {
                            Image(systemName: "sparkles")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.indigo)
                                .frame(width: 28, height: 28)
                                .background(Color.indigo.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                            Text(entry.title)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)

                            Spacer(minLength: 0)
                        }
                        .padding(12)
                        .background(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.62), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(updatesBackground)
        .navigationTitle("Ultimi aggiornamenti")
    }

    private var updatesBackground: some View {
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

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Novita e miglioramenti")
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)

            Text("Storico aggiornamenti della piattaforma, allineato alla versione web")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .updatesGlassCard()
    }
}

private struct UpdateEntry: Identifiable {
    let id = UUID()
    let title: String
}

private struct UpdatesGlassCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular.tint(.indigo.opacity(0.06)), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        } else {
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.primary.opacity(0.07), lineWidth: 1)
                }
        }
    }
}

private extension View {
    func updatesGlassCard() -> some View {
        modifier(UpdatesGlassCardModifier())
    }
}
