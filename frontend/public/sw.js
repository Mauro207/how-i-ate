self.addEventListener('push', (event) => {
  let data = { title: 'How I Ate', body: 'Nuovo aggiornamento disponibile!', url: '/' };

  const ua = self.navigator?.userAgent || '';
  const isSafari = /Safari/i.test(ua) && !/Chrome|Chromium|CriOS|Edg|OPR|FxiOS|Firefox/i.test(ua);

  const formatTitle = (title) => {
    if (!title) return 'How I Ate';
    const cleaned = title.replace(/\s*-\s*HowIAte\s*$/i, '').trim();
    return isSafari ? cleaned : `${cleaned} - HowIAte`;
  };

  if (event.data) {
    try {
      data = { ...data, ...event.data.json() };
    } catch {
      data.body = event.data.text();
    }
  }

  event.waitUntil(
    self.registration.showNotification(formatTitle(data.title), {
      body: data.body,
      icon: '/icons/icon-192x192.png',
      badge: '/icons/icon-192x192.png',
      data: { url: data.url || '/' }
    })
  );
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const targetUrl = event.notification.data?.url || '/';
  event.waitUntil(
    clients
      .matchAll({ type: 'window', includeUncontrolled: true })
      .then((clientList) => {
        for (const client of clientList) {
          if (client.url === targetUrl && 'focus' in client) return client.focus();
        }
        if (clients.openWindow) return clients.openWindow(targetUrl);
      })
  );
});

// ─── Cache per le API dei ristoranti ────────────────────────────────────────
const API_CACHE = 'hia-api-v1';

// Pattern di URL da memorizzare (solo GET)
const CACHEABLE_PATTERNS = [
  /\/api\/restaurants\/[a-f0-9]{24}$/,          // GET /api/restaurants/:id
  /\/api\/reviews\/restaurant\/[a-f0-9]{24}$/,  // GET /api/reviews/restaurant/:id
];

self.addEventListener('fetch', (event) => {
  if (event.request.method !== 'GET') return;

  const url = new URL(event.request.url);
  if (!CACHEABLE_PATTERNS.some((p) => p.test(url.pathname))) return;

  // Strategia stale-while-revalidate:
  // 1. Serve subito la risposta dalla cache (se disponibile)
  // 2. Aggiorna la cache in background con la risposta di rete
  event.respondWith(
    caches.open(API_CACHE).then(async (cache) => {
      const cached = await cache.match(event.request.url);

      const networkPromise = fetch(event.request)
        .then((res) => {
          if (res.ok) cache.put(event.request.url, res.clone());
          return res;
        })
        .catch(() => null);

      if (cached) {
        // Cache hit: servi subito e aggiorna in background
        event.waitUntil(networkPromise);
        return cached;
      }

      // Cache miss: aspetta la rete
      return networkPromise ?? new Response(JSON.stringify({ message: 'Offline' }), {
        status: 503,
        headers: { 'Content-Type': 'application/json' }
      });
    })
  );
});

// Attiva subito il SW senza aspettare il reload
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) =>
  event.waitUntil(
    Promise.all([
      clients.claim(),
      // Rimuovi versioni precedenti della cache API
      caches.keys().then((keys) =>
        Promise.all(
          keys
            .filter((k) => k.startsWith('hia-') && k !== API_CACHE)
            .map((k) => caches.delete(k))
        )
      ),
    ])
  )
);
