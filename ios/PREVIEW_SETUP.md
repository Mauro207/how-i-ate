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

## Navigare tutta l'interfaccia dal Canvas

1. Apri `ios/AppRootView.swift`.
2. Nel canvas usa una delle preview:
	- `App Shell - Admin`
	- `App Shell - User`
3. Queste preview partono gia autenticate, quindi puoi passare tra tutte le tab senza fare login.

## Nota

Le preview usano `https://example.com/api` come base URL fittizia e dati mock locali, cosi il canvas non dipende dal backend per il rendering iniziale.

In modalita Preview, il login reale e disabilitato (`Anteprima attiva: login disabilitato`) per evitare chiamate HTTP accidentali dal canvas.
