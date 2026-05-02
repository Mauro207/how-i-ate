# Design System - How I Ate

## Scopo
Questo documento definisce il design system operativo del progetto, pensato per guidare modifiche future fatte da AI o da sviluppatori.

Obiettivo: mantenere coerenza visiva e UX con cio che e gia consolidato nel frontend, evitando di propagare pattern legacy o non ottimizzati.

## Ambito
- Frontend Angular (standalone) in `frontend/`
- Stile basato su Tailwind utility-first + CSS locale per casi specifici
- Tema light/dark automatico basato su `prefers-color-scheme` (non esiste toggle manuale)

## Stack UI reale da rispettare
- Angular 21 standalone components
- Tailwind CSS 3 (config minimale, senza token custom in `tailwind.config.js`)
- CSS component-scoped per pattern particolari (es. mobile bottom nav, updates markdown)
- Nessun uso reale di Angular Material

Nota: anche se la palette richiama Material Design 3 (seed viola), il progetto non usa componenti Material. Il riferimento MD3 qui e solo a livello di token cromatici e gerarchia delle superfici.

## Principi guida
- Utility-first come default: preferire classi Tailwind in template.
- CSS locale solo quando serve (animazioni dedicate, micro-layout complessi, selettori non pratici in utility).
- Superfici morbide: molto uso di `rounded-xl`/`rounded-2xl`, bordi leggeri, shadow leggere.
- Palette primaria consistente (violet) su CTA, chip attivi, accenti e iconografia.
- Dark mode sempre prevista in parallelo con varianti `dark:`.
- Mobile-first con attenzione a safe area e navigazione bottom su schermi piccoli.

## Design tokens (stato attuale consolidato)

### Colori
Primari (brand-like):
- Primary 500: `#6750a4`
- Primary hover: `#5a4494`
- Primary deep text/accent: `#4527a0` o `#4a3880`
- Primary container light: `#f3eeff`
- Primary container strong light: `#ede9fb`
- Primary on dark accent: `#d0bcff`

Superfici:
- Page gradient light: `from-[#f3eeff] to-[#faf5ff]`
- Page gradient dark: `dark:from-[#1e1a2b] dark:to-[#1C1B1F]`
- Card light: `bg-white`
- Card dark: `dark:bg-[#2b2930]`
- Body dark base: `dark:bg-[#121212]`

Neutri:
- Testo primario light: `text-gray-900`
- Testo secondario light: `text-gray-500` / `text-gray-600`
- Testo primario dark: `dark:text-white`
- Testo secondario dark: `dark:text-gray-300` / `dark:text-gray-400`
- Bordi light: `border-gray-100` / `border-gray-200`
- Bordi dark: `dark:border-white/5` / `dark:border-white/10`

Stati semantici:
- Error: base `red-50/red-700/red-200` + varianti dark `red-900/...`
- Success: base `emerald-50/emerald-700/emerald-200` + dark
- Info: base `blue-50/blue-700/blue-200` + dark
- Warning: base `amber-50/amber-700/amber-200` + dark

### Radius
- Input/button standard: `rounded-xl`
- Card/surface principali: `rounded-2xl`
- Chip/pill: `rounded-full`

### Ombre
- Card standard: `shadow-sm`
- Elementi elevati specifici (hero image, login card): `shadow-lg`/`shadow-2xl` solo quando motivato

### Spaziatura e layout
- Page container: `px-4 sm:px-6 lg:px-8`
- Max width tipiche: `max-w-5xl`, `max-w-6xl`, `max-w-7xl`
- Padding bottom mobile ricorrente: `pb-28` (in aggiunta al safe-space globale)

## Tipografia
Sistema attuale (senza font custom):
- Hero title pagina: `text-3xl font-bold`
- Section title/card title: `text-xl font-semibold` oppure `text-lg font-semibold`
- Label overline: `text-xs font-semibold uppercase tracking-widest` o `tracking-[0.15em]`
- Body: `text-sm` / `text-base`
- Micro label/badge: `text-[10px]` o `text-[11px]`

Regola: mantenere gerarchie gia presenti, evitando scale tipografiche nuove non necessarie.

## Pattern UI canonici

### 1) Page shell
- Wrapper con gradiente light/dark coerente
- `app-navigation` in alto
- Content container centrato con `max-w-*`

Ricetta base:
- Root: `min-h-screen bg-gradient-to-b from-[#f3eeff] to-[#faf5ff] dark:from-[#1e1a2b] dark:to-[#1C1B1F]`
- Main: `px-4 pt-6 pb-28 mx-auto sm:px-6 lg:px-8`

### 2) Card surface
Ricetta:
- `bg-white dark:bg-[#2b2930]`
- `border border-gray-100 dark:border-white/5`
- `rounded-2xl shadow-sm`

### 3) Primary button
Ricetta:
- `bg-[#6750a4] text-white`
- `hover:bg-[#5a4494]`
- `rounded-xl`
- `font-semibold`
- `focus:outline-none focus:ring-2 focus:ring-[#6750a4]/40`
- Disabled: `disabled:opacity-50 disabled:cursor-not-allowed`

### 4) Input field
Ricetta:
- `bg-gray-50 dark:bg-white/5`
- `border border-gray-200 dark:border-white/10`
- `text-gray-900 dark:text-white`
- `placeholder-gray-400 dark:placeholder-gray-500`
- `rounded-xl`
- `focus:ring-2 focus:ring-[#6750a4]/40 focus:border-[#6750a4] dark:focus:border-[#d0bcff]`

### 5) Chip e badge
Chip informativo:
- `bg-[#ede9fb] text-[#4527a0] dark:bg-[#6750a4]/25 dark:text-[#d0bcff]`

Chip attivo filtro:
- `bg-[#f3eeff] dark:bg-[#6750a4]/20 text-[#6750a4] dark:text-[#d0bcff] ring-2 ring-[#6750a4]/40 dark:ring-[#d0bcff]/40`

### 6) Lista interattiva
Elementi cliccabili:
- `transition cursor-pointer`
- `hover:bg-[#f3eeff]/60 dark:hover:bg-white/[0.03]`
- separatori con `divide-y divide-gray-100 dark:divide-white/5`

### 7) Loading e skeleton
- Spinner con accento primary (`text-[#6750a4] dark:text-[#d0bcff] animate-spin`)
- Skeleton con `animate-pulse` e blocchi `bg-gray-100 dark:bg-white/5`

## Navigazione
- Desktop: top floating nav card con blur leggero
- Mobile: bottom navigation fissa con safe area
- Variabile globale disponibile: `--mobile-bottom-safe-space`
- Su mobile, il contenuto sotto `app-navigation` riceve padding bottom automatico

Regola: ogni nuova pagina deve essere testata su viewport mobile per evitare overlap con bottom nav.

## Dark mode
- Guidata da media query (`prefers-color-scheme`) e varianti Tailwind `dark:`
- Non introdurre toggle manuale finche non viene definita una strategia globale
- Ogni nuovo componente deve avere coppie light/dark esplicite per:
  - background
  - testo
  - border
  - hover/focus

## Motion e interazioni
- Animazioni brevi e funzionali (`transition`, `animate-spin`, `animate-pulse`)
- Animazioni custom limitate a casi mirati (es. `wave-emoji`, fade menu)
- Rispettare `prefers-reduced-motion` quando si aggiungono animazioni non essenziali

## Accessibilita
- Focus ring sempre visibile su controlli interattivi
- Contrasto mantenuto in light e dark
- Uso di `aria-label`, `role="switch"`, `aria-checked` gia presente: continuare su questo standard
- Touch target confortevoli su mobile (bottoni >= 36-40px dove possibile)

## Cosa includere come standard
In nuove implementazioni, prendere come riferimento soprattutto:
- `restaurants`, `search`, `rankings`, `user-rankings`, `suggestions`, `settings` (struttura generale)
- `navigation` (pattern responsive e safe-area)
- `ranking-widget` (chip/filter/list style)

## Cosa NON includere nel design system (legacy o non ottimizzato)
Questi pattern esistono nel codice ma non vanno usati come base per nuove UI:

1. Palette indigo non coerente col primary viola
- Esempi: login e loader root con `indigo-*`
- Motivo: rompe la coerenza cromatica primaria del prodotto

2. Blocchi CSS markdown duplicati e confliggenti in updates
- In `updates.component.css` ci sono regole duplicate per `.markdown-content` (set violet + set indigo)
- Motivo: rischio inconsistenza visiva e override imprevedibili

3. Uso estensivo di `::ng-deep` fuori da casi strettamente necessari
- Ammesso solo quando non c e alternativa pratica (es. rendering markdown esterno)

4. Surface troppo elevate senza motivo UX
- Evitare `shadow-2xl` e combinazioni heavy se non in schermate isolate (es. login attuale)

## Regole operative per AI (obbligatorie)
Quando generi o modifichi UI in questo progetto:
- Usa Tailwind come prima scelta.
- Mantieni palette primary viola (`#6750a4` family) come unico accento principale.
- Applica sempre variante dark per ogni nuovo blocco visuale.
- Usa card pattern canonico (`bg-white/dark:bg-[#2b2930] + border + rounded-2xl + shadow-sm`).
- Usa bottoni primari con `bg-[#6750a4]` e hover `#5a4494`.
- Riusa pattern di input e messaggi stato gia consolidati.
- Evita introdurre nuovi token hardcoded se non strettamente necessario.
- Se serve un nuovo token, preferisci allinearlo alla famiglia primary esistente.

## Regole operative per MD3 + Tailwind
- Interpretare MD3 a livello di ruoli colore/superficie, non a livello di component library Material.
- Non introdurre componenti Material o API Material senza decisione architetturale esplicita.
- Se un pattern MD3 e in conflitto con la UI consolidata Tailwind del progetto, prevale la coerenza con la UI consolidata.

## Checklist rapida per PR UI
- Coerenza palette con primary viola
- Light/dark completi
- Card/button/input conformi ai pattern canonici
- Focus/hover/disabled presenti
- Mobile + safe area verificati
- Nessun riuso di pattern legacy indicati sopra
