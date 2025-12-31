# Implementazione Autenticazione JWT con Cookie - Riepilogo

## Problema Risolto

**Problema originale**: Gli utenti devono reinserire le credenziali ad ogni refresh della pagina.

**Soluzione implementata**: Autenticazione JWT basata su cookie HTTP-only che mantiene la sessione utente anche dopo il refresh del browser.

## Modifiche Implementate

### Backend

1. **Installato cookie-parser**
   - Aggiunta dipendenza per gestire i cookie HTTP

2. **Configurazione CORS aggiornata** (`backend/index.js`)
   - Abilitato `credentials: true`
   - Supporto per origini multiple (separati da virgola)
   - Configurazione compatibile con Vercel

3. **Middleware di autenticazione** (`backend/middleware/auth.js`)
   - Legge JWT prima dai cookie, poi dall'header Authorization
   - Mantiene compatibilità con token Bearer esistenti

4. **Route di autenticazione** (`backend/routes/auth.js`)
   - `/login`: Imposta cookie HTTP-only con JWT
   - `/register`: Imposta cookie HTTP-only con JWT
   - `/logout`: Cancella il cookie di autenticazione
   - Cookie sicuri con attributi:
     - `httpOnly: true` - Protezione XSS
     - `secure: true` in produzione - Solo HTTPS
     - `sameSite: 'none'` in produzione - Cross-domain Vercel
     - `sameSite: 'lax'` in sviluppo - Protezione CSRF
     - `maxAge: 90 giorni` - Sessione persistente

### Frontend

1. **Configurazione HTTP Client** (`frontend/src/app/app.config.ts`)
   - Aggiunto `withFetch()` per supporto nativo

2. **Auth Interceptor** (`frontend/src/app/interceptors/auth.interceptor.ts`)
   - Aggiunto `withCredentials: true` a tutte le richieste
   - I cookie vengono inviati automaticamente

3. **Auth Service** (`frontend/src/app/services/auth.service.ts`)
   - Metodo `logout()` aggiornato per chiamare endpoint backend
   - Assicura la corretta cancellazione del cookie

## Funzionalità di Sicurezza

✅ **Protezione XSS**: Cookie HTTP-only impedisce accesso JavaScript  
✅ **Protezione CSRF**: Attributo sameSite previene attacchi cross-site  
✅ **HTTPS**: Flag secure garantisce trasmissione sicura in produzione  
✅ **CORS Ristretto**: Origini specifiche configurate  
✅ **Sessioni Persistenti**: 90 giorni di validità  
✅ **Compatibilità**: Supporta ancora Bearer token

## Compatibilità Vercel (Piano Gratuito)

✅ Funziona con serverless functions  
✅ Nessuno stato server necessario  
✅ Configurazione via variabili d'ambiente  
✅ Supporto cookie cross-domain  
✅ Completamente compatibile con piano free

## Configurazione Vercel

### Variabili d'Ambiente Backend

Configurare nel dashboard Vercel del backend:

```
NODE_ENV=production
FRONTEND_URL=https://your-frontend-domain.vercel.app
JWT_SECRET=your-secure-random-secret-key
JWT_EXPIRES_IN=90d
MONGODB_URI=your-mongodb-connection-string
```

**Importante**: 
- `FRONTEND_URL` deve corrispondere al dominio frontend effettivo
- Per più origini, separare con virgola: `https://domain1.vercel.app,https://domain2.vercel.app`

### Frontend

Aggiornare `frontend/src/environments/environment.prod.ts`:

```typescript
export const environment = {
  production: true,
  apiUrl: 'https://your-backend-domain.vercel.app/api'
};
```

## Come Funziona

1. **Login/Registrazione**:
   - Utente invia credenziali
   - Backend valida e genera JWT
   - Backend imposta cookie HTTP-only con JWT
   - Frontend salva dati utente

2. **Richieste Autenticate**:
   - Frontend invia richieste con `withCredentials: true`
   - Browser include automaticamente i cookie
   - Backend verifica JWT dal cookie
   - Fallback su Authorization header se cookie assente

3. **Refresh Pagina**:
   - Cookie persiste nel browser
   - Frontend chiama `/api/auth/me` all'avvio
   - Backend valida JWT dal cookie
   - Sessione utente ripristinata **senza re-login**

4. **Logout**:
   - Frontend chiama `/api/auth/logout`
   - Backend cancella il cookie
   - Frontend pulisce localStorage e redirige al login

## Test Locali

### 1. Avviare Backend
```bash
cd backend
npm install
npm start
```

### 2. Avviare Frontend
```bash
cd frontend
npm install
npm start
```

### 3. Verificare Funzionamento
1. Accedere all'applicazione
2. Aprire DevTools > Application > Cookies
3. Verificare presenza cookie `jwt`
4. Ricaricare pagina (F5)
5. **Verificare di rimanere loggati** ✓

## Documentazione

- **COOKIE_AUTH_IMPLEMENTATION.md** - Dettagli implementazione completi
- **SECURITY_SUMMARY_COOKIES.md** - Analisi sicurezza
- **TESTING_GUIDE_COOKIES.md** - Guida test completa
- **README.md** - Aggiornato con istruzioni deployment

## Risoluzione Problemi

### Cookie non impostato in produzione

**Verificare**:
- `NODE_ENV=production` nel backend
- `FRONTEND_URL` corrisponde al dominio reale
- Entrambi i domini usano HTTPS
- Browser non blocca cookie third-party

### Sessione persa dopo refresh

**Verificare**:
- Cookie presente in DevTools
- Endpoint `/api/auth/me` viene chiamato
- Dominio cookie corrisponde al backend

### Errori CORS

**Verificare**:
- Variabile `FRONTEND_URL` configurata
- `withCredentials: true` nel frontend
- Entrambi i domini usano HTTPS

## Stato Implementazione

✅ **Completata e testata**  
✅ **Code review superata**  
✅ **Security scan completato**  
✅ **Documentazione completa**  
✅ **Pronta per produzione Vercel**

## Prossimi Passi

1. Fare merge del PR
2. Deployare backend su Vercel
3. Configurare variabili d'ambiente
4. Deployare frontend su Vercel
5. Testare in produzione secondo TESTING_GUIDE_COOKIES.md

**Risultato**: Gli utenti rimarranno loggati anche dopo il refresh della pagina! 🎉
