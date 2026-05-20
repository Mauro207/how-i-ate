# Migrazione verso iOS Nativo (swift-ios)

## Obiettivo

Portare nel branch `swift-ios` tutto il riusabile dell'app esistente in una base Swift/SwiftUI pronta per evoluzione iOS.

## Feature mappate dal progetto attuale

- Auth: login/register/me/profile
- Ristoranti: lista, dettaglio, ricerca
- Recensioni: lista e creazione da dettaglio
- Recensioni: lista, creazione, modifica ed eliminazione (proprie)
- Rankings: globali e user-specific
- Suggestion: creazione e lista (admin)
- Suggestion admin: approve/reject
- Admin restaurants: create/edit/delete
- Settings: profilo sessione e logout

## Endpoint coperti dalla base iOS

- `POST /api/auth/login`
- `POST /api/auth/register`
- `GET /api/auth/me`
- `PUT /api/auth/profile`
- `GET /api/restaurants`
- `GET /api/restaurants/:id`
- `GET /api/restaurants/search?q=`
- `GET /api/reviews/restaurant/:restaurantId`
- `POST /api/reviews/restaurant/:restaurantId`
- `GET /api/reviews/rankings/global`
- `GET /api/reviews/rankings/user/:userId`
- `POST /api/suggestions`
- `GET /api/suggestions`

## Riutilizzo logica business

- Porting `toRankingAverage` e ordinamento ranking in `Utils/RankingCalculator.swift`.
- Compatibilita payload backend tramite decoding flessibile `id`/`_id`.

## Parti restate backend-only o web-only

- Telegram bot e webhook
- PWA / Service Worker
- Web push (VAPID browser)
- Componenti Angular e Tailwind

## Prossime estensioni consigliate

1. Schermate dettaglio ristorante + CRUD review completo.
2. Flussi admin/superadmin (approve/reject suggestions, create user/admin).
3. Push iOS con APNs + endpoint notifiche dedicati (se previsti).
4. UI test e unit test dei servizi con mocking URLSession.
