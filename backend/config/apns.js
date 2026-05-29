const apn = require('apn');

const normalizePrivateKey = (value) => {
  if (!value) return '';
  const trimmed = value.trim();
  return trimmed.includes('\\n') ? trimmed.replace(/\\n/g, '\n') : trimmed;
};

const teamId = process.env.APNS_TEAM_ID;
const keyId = process.env.APNS_KEY_ID;
const bundleId = process.env.APNS_BUNDLE_ID;
const privateKey = normalizePrivateKey(process.env.APNS_PRIVATE_KEY);
const production = process.env.APNS_PRODUCTION === 'true';

let apnsConfigured = Boolean(teamId && keyId && bundleId && privateKey);
let provider = null;

if (apnsConfigured) {
  try {
    provider = new apn.Provider({
      token: {
        key: privateKey,
        keyId,
        teamId
      },
      production
    });
    console.log(`[apns] Configurato correttamente (${production ? 'production' : 'sandbox'}).`);
  } catch (error) {
    apnsConfigured = false;
    console.error('[apns] Configurazione non valida:', error.message);
  }
} else {
  console.warn('[apns] Non configurato. Le notifiche native iOS non funzioneranno.');
}

const getAPNSConfig = () => ({
  apnsConfigured,
  bundleId,
  production
});

module.exports = {
  provider,
  getAPNSConfig
};
