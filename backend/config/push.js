const webpush = require('web-push');

/**
 * Restituisce la configurazione push leggendo le env vars a runtime (no cache),
 * così funziona correttamente sia in locale sia in produzione indipendentemente
 * dall'ordine di caricamento dei moduli.
 */
function getPushConfig() {
  const isProduction = process.env.NODE_ENV === 'production';
  let vapidPublicKey = process.env.VAPID_PUBLIC_KEY;
  let vapidPrivateKey = process.env.VAPID_PRIVATE_KEY;

  // In sviluppo genera chiavi temporanee se non configurate, evitando 503 locali.
  if ((!vapidPublicKey || !vapidPrivateKey) && !isProduction) {
    const generated = webpush.generateVAPIDKeys();
    vapidPublicKey = generated.publicKey;
    vapidPrivateKey = generated.privateKey;
    console.warn('[push] VAPID non configurate: uso chiavi temporanee per sviluppo locale.');
  }

  const pushConfigured = !!(vapidPublicKey && vapidPrivateKey);

  if (pushConfigured) {
    webpush.setVapidDetails(
      process.env.VAPID_SUBJECT || 'mailto:admin@howiateapp.com',
      vapidPublicKey,
      vapidPrivateKey
    );
  }

  return { pushConfigured, vapidPublicKey };
}

module.exports = {
  webpush,
  getPushConfig
};
