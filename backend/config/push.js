const webpush = require('web-push');
const fs = require('fs');
const path = require('path');

const isProduction = process.env.NODE_ENV === 'production';
let vapidPublicKey = process.env.VAPID_PUBLIC_KEY;
let vapidPrivateKey = process.env.VAPID_PRIVATE_KEY;

// In sviluppo: se le chiavi non ci sono, le genera e le persiste nel .env
if ((!vapidPublicKey || !vapidPrivateKey) && !isProduction) {
  const envPath = path.join(__dirname, '..', '.env');
  const generated = webpush.generateVAPIDKeys();
  vapidPublicKey = generated.publicKey;
  vapidPrivateKey = generated.privateKey;

  console.warn('[push] VAPID non configurate: genero chiavi stabili e le scrivo in .env');
  console.warn('[push] VAPID_PUBLIC_KEY:', vapidPublicKey);

  try {
    let envContent = fs.existsSync(envPath) ? fs.readFileSync(envPath, 'utf8') : '';

    const upsert = (content, key, value) => {
      const regex = new RegExp(`^${key}=.*$`, 'm');
      const line = `${key}=${value}`;
      return regex.test(content) ? content.replace(regex, line) : content + `\n${line}`;
    };

    envContent = upsert(envContent, 'VAPID_PUBLIC_KEY', vapidPublicKey);
    envContent = upsert(envContent, 'VAPID_PRIVATE_KEY', vapidPrivateKey);
    fs.writeFileSync(envPath, envContent, 'utf8');
    console.warn('[push] Chiavi VAPID scritte in .env — riavvia il server per applicarle stabilmente.');
  } catch (err) {
    console.error('[push] Impossibile scrivere le chiavi VAPID in .env:', err.message);
  }
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

module.exports = { webpush, getPushConfig };
