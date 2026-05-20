# How I Ate iOS (SwiftUI)

Questa cartella contiene la base nativa iOS per il progetto, portata dal frontend Angular verso Swift/SwiftUI.

## Cosa e stato portato

- Modelli dati principali: `User`, `Restaurant`, `Review`, `Suggestion`, `RankingItem`.
- Networking nativo con `URLSession` e gestione errori API.
- Gestione sessione JWT con storage sicuro in Keychain.
- Servizi feature allineati agli endpoint backend:
  - Auth (`/api/auth/*`)
  - Restaurants (`/api/restaurants/*`)
  - Reviews (`/api/reviews/*`)
  - Rankings (`/api/reviews/rankings/*`)
  - Suggestions (`/api/suggestions/*`)
- Porting utility ranking (`toRankingAverage` + sort) in Swift.
- UI MVP SwiftUI:
  - Login
  - Lista ristoranti
  - Dettaglio ristorante
  - Creazione recensione da dettaglio
  - Modifica/eliminazione recensione propria con conferma
  - Rankings globali
  - Pannello Admin con:
    - suggestions (approve/reject con conferma)
    - ristoranti (create/edit/delete con conferma)
  - Settings/Logout

## Cosa NON e stato portato (web-only)

- PWA/Service Worker
- Manifest web
- Componenti install banner web
- Push Web (VAPID browser)
- Integrazione Telegram bot (resta backend)

## Struttura

```text
ios/
  HowIAteApp.swift
  AppRootView.swift
  Core/
  Models/
  Services/
  Features/
  Utils/
```

## Integrazione in Xcode

1. Crea un nuovo progetto iOS App (SwiftUI) in Xcode.
2. Copia o trascina i file di questa cartella nel target app.
3. Imposta la base URL API in `Core/Config/AppConfig.swift`.
4. Esegui su simulatore/dispositivo.

Alternativa rapida con XcodeGen:

1. Installa `xcodegen` (se assente).
2. Da cartella `ios`, esegui `xcodegen generate`.
3. Apri `HowIAte.xcodeproj` generato.

## Endpoint backend usati

- `POST /api/auth/login`
- `POST /api/auth/register`
- `GET /api/auth/me`
- `PUT /api/auth/profile`
- `GET /api/restaurants`
- `GET /api/restaurants/:id`
- `GET /api/reviews/restaurant/:restaurantId`
- `POST /api/reviews/restaurant/:restaurantId`
- `GET /api/reviews/rankings/global`
- `GET /api/reviews/rankings/user/:userId`
- `POST /api/suggestions`

## Note

- Il backend continua a essere la source of truth per auth e autorizzazioni role-based.
- Le schermate admin/superadmin possono essere aggiunte sopra questa base mantenendo i servizi gia presenti.