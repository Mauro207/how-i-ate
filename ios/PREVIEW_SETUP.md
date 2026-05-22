# Xcode Live Preview Setup

Le preview SwiftUI sono state migrate a macro `#Preview` (Xcode 15+) e isolate in file separati, cosi il canvas ricarica solo il modulo modificato.

## File preview dedicati

- `Shared/Previews/AppRootView+Preview.swift`
- `Features/Admin/AdminAddPlaceView+Preview.swift`
- `Features/Suggestions/AddSuggestionTabView+Preview.swift`
- `Features/Rankings/MyRatingsView+Preview.swift`

Inoltre, per ridurre il costo di rebuild nella sezione ranking, la row e stata estratta in:

- `Features/Rankings/Components/MyRatingRowView.swift`

## Come attivarla in Xcode

1. Apri `ios/HowIAte.xcodeproj`.
2. Seleziona lo scheme `HowIAte` in configurazione `Debug`.
3. Apri uno dei file preview dedicati elencati sopra.
4. Usa `Editor > Canvas` e premi `Resume`.
5. Quando fai modifiche UI, lavora direttamente sul file componente o sul suo file preview dedicato.

## Preview disponibili

Nel canvas trovi (tra le altre):

- `App Shell - Live API`
- `App Shell - Mock Admin`
- `App Shell - Mock State Playground` (usa `@Previewable @State`)
- `Admin Add Place`
- `Add Suggestion`
- `My Ratings Screen`
- `My Ratings Row Playground` (usa `@Previewable @State`)

## Nota su rete e velocita

Le preview mock usano `https://example.com/api` come base URL fittizia e dati locali, cosi il rendering iniziale non dipende dal backend.

Quando la rete preview e disabilitata (preview mock o `HOWIATE_PREVIEW_LIVE_DATA=0`), il login reale mostra `Anteprima attiva: login disabilitato`.

Con rete preview disabilitata, i caricamenti automatici rete (home/ranking/impostazioni/i tuoi voti) sono sospesi per migliorare tempi e stabilita del canvas.

Per forzare la sospensione rete anche in `Live API`, imposta la variabile ambiente `HOWIATE_PREVIEW_LIVE_DATA=0`.
