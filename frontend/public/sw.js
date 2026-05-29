self.addEventListener('push', (event) => {
  let data = {
    title: 'How I Ate',
    body: 'Nuovo aggiornamento disponibile!',
    url: '/',
    tag: 'how-i-ate',
    actions: []
  };

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

  const notificationOptions = {
      body: data.body,
      icon: '/icons/icon-192x192.png',
      badge: '/icons/icon-192x192.png',
      tag: data.tag || 'how-i-ate',
      renotify: false,
      requireInteraction: Boolean(data.requireInteraction),
      data: { url: data.url || '/' }
  };

  if (Array.isArray(data.actions) && data.actions.length) {
    notificationOptions.actions = data.actions.slice(0, 2);
  }

  event.waitUntil(
    self.registration.showNotification(formatTitle(data.title), notificationOptions)
  );
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const targetPath = event.action === 'review' ? '/restaurants' : (event.notification.data?.url || '/');
  const targetUrl = new URL(targetPath, self.location.origin).href;

  event.waitUntil(
    clients
      .matchAll({ type: 'window', includeUncontrolled: true })
      .then((clientList) => {
        for (const client of clientList) {
          const clientUrl = new URL(client.url);
          if (clientUrl.href === targetUrl && 'focus' in client) return client.focus();
        }
        if (clients.openWindow) return clients.openWindow(targetUrl);
      })
  );
});

// ─── Cache per le API dei ristoranti ────────────────────────────────────────
const API_CACHE = 'hia-api-v2';

// Pattern di URL da memorizzare (solo GET)
const CACHEABLE_PATTERNS = [
  /\/api\/restaurants\/[a-f0-9]{24}$/,          // GET /api/restaurants/:id
  /\/api\/reviews\/restaurant\/[a-f0-9]{24}$/,  // GET /api/reviews/restaurant/:id
];

self.addEventListener('fetch', (event) => {
  if (event.request.method !== 'GET') return;

  const url = new URL(event.request.url);
  if (!CACHEABLE_PATTERNS.some((p) => p.test(url.pathname))) return;

  // Strategia network-first con fallback sulla cache:
  // - Se la rete è disponibile → dati sempre freschi, cache aggiornata
  // - Se la rete fallisce (offline) → fallback sulla cache
  event.respondWith(
    caches.open(API_CACHE).then(async (cache) => {
      try {
        const res = await fetch(event.request);
        if (res.ok) cache.put(event.request.url, res.clone());
        return res;
      } catch {
        // Rete non disponibile: usa la cache come fallback offline
        const cached = await cache.match(event.request.url);
        return cached ?? new Response(JSON.stringify({ message: 'Offline' }), {
          status: 503,
          headers: { 'Content-Type': 'application/json' }
        });
      }
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
