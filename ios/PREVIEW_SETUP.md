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
	- `App Shell - Live API` (dati reali backend)
	- `App Shell - Mock Admin`
	- `App Shell - Mock User`
3. La preview `Live API` usa `AppConfig.apiBaseURL` e prova a riusare la sessione reale salvata (token Keychain).
4. Se non c'e sessione, puoi fare login direttamente in Canvas (con backend reale).

## Nota

Le preview `Mock` usano `https://example.com/api` come base URL fittizia e dati mock locali, cosi il canvas non dipende dal backend per il rendering iniziale.

Quando la rete preview e disabilitata (es. preview `Mock` o `HOWIATE_PREVIEW_LIVE_DATA=0`), il login reale mostra `Anteprima attiva: login disabilitato`.

Con rete preview disabilitata, i caricamenti automatici rete (home/ranking/impostazioni/i tuoi voti) sono sospesi, cosi puoi navigare senza errori API su `example.com`.

Per forzare la sospensione rete anche in `Live API`, imposta la variabile ambiente `HOWIATE_PREVIEW_LIVE_DATA=0`.
