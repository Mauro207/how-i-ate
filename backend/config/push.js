const webpush = require('web-push');

// Inizializza le chiavi VAPID UNA SOLA VOLTA al caricamento del modulo
const isProduction = process.env.NODE_ENV === 'production';
let vapidPublicKey = process.env.VAPID_PUBLIC_KEY;
let vapidPrivateKey = process.env.VAPID_PRIVATE_KEY;

if ((!vapidPublicKey || !vapidPrivateKey) && !isProduction) {
  const generated = webpush.generateVAPIDKeys();
  vapidPublicKey = generated.publicKey;
  vapidPrivateKey = generated.privateKey;
  console.warn('[push] VAPID non configurate: uso chiavi temporanee per sviluppo locale.');
  console.warn('[push] VAPID_PUBLIC_KEY temporanea:', vapidPublicKey);
}

const pushConfigured = !!(vapidPublicKey && vapidPrivateKey);

if (pushConfigured) {
  webpush.setVapidDetails(
    process.env.VAPID_SUBJECT || 'mailto:admin@howiateapp.com',
    vapidPublicKey,
    vapidPrivateKey
  );
  console.log('[push] VAPID configurato correttamente.');
} else {
  console.warn('[push] VAPID non configurato. Le notifiche push non funzioneranno.');
}

function getPushConfig() {
  return { pushConfigured, vapidPublicKey };
}

module.exports = {
  webpush,
  getPushConfig
};
