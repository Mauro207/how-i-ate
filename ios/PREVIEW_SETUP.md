# Xcode Live Preview Setup

Questi file abilitano anteprime SwiftUI immediate nel progetto iOS:

- `AppRootView.swift` -> `AppRootView_Previews`
- `Features/Admin/AdminAddPlaceView.swift` -> `AdminAddPlaceView_Previews`
- `Features/Suggestions/AddSuggestionTabView.swift` -> `AddSuggestionTabView_Previews`
- `Features/Rankings/MyRatingsView.swift` -> `MyRatingsView_Previews`

## Come attivarla in Xcode

1. Apri `ios/HowIAte.xcodeproj`.
2. Seleziona lo scheme `HowIAte` in configurazione `Debug`.
3. Apri uno dei file con `PreviewProvider`.
4. Usa `Editor > Canvas` e premi `Resume`.
5. Per anteprime veloci, usa le preview già isolate da chiamate rete iniziali (`disableAutoLoad` / `disableInitialLoad`).

## Nota

Le preview usano `https://example.com/api` come base URL fittizia e dati mock locali, cosi il canvas non dipende dal backend per il rendering iniziale.
