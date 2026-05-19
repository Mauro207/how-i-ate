const path = require('path');
const dotenv = require('dotenv');

dotenv.config({ path: path.join(__dirname, '..', '.env'), override: true });

const TELEGRAM_BOT_TOKEN = process.env.TELEGRAM_BOT_TOKEN;
const BACKEND_URL = (process.env.BACKEND_URL || '').replace(/\/$/, '');
const TELEGRAM_WEBHOOK_SECRET = process.env.TELEGRAM_WEBHOOK_SECRET || '';

if (!TELEGRAM_BOT_TOKEN) {
  console.error('Missing TELEGRAM_BOT_TOKEN in backend/.env');
  process.exit(1);
}

const telegramApi = async (method, payload = {}) => {
  const response = await fetch(`https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/${method}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload)
  });

  const data = await response.json();
  if (!data.ok) {
    throw new Error(data.description || `Telegram API error on ${method}`);
  }

  return data.result;
};

const setWebhook = async () => {
  if (!BACKEND_URL) {
    throw new Error('Missing BACKEND_URL in backend/.env');
  }

  const webhookUrl = `${BACKEND_URL}/api/telegram/webhook`;
  const payload = { url: webhookUrl };

  if (TELEGRAM_WEBHOOK_SECRET) {
    payload.secret_token = TELEGRAM_WEBHOOK_SECRET;
  }

  await telegramApi('setWebhook', payload);
  console.log(`[telegram] Webhook impostato su ${webhookUrl}`);
};

const getWebhookInfo = async () => {
  const response = await fetch(`https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getWebhookInfo`);
  const data = await response.json();

  if (!data.ok) {
    throw new Error(data.description || 'Telegram API error on getWebhookInfo');
  }

  const info = data.result || {};
  console.log(JSON.stringify({
    url: info.url,
    has_custom_certificate: info.has_custom_certificate,
    pending_update_count: info.pending_update_count,
    last_error_date: info.last_error_date || null,
    last_error_message: info.last_error_message || null
  }, null, 2));
};

const setCommands = async () => {
  const commands = [
    { command: 'start', description: 'Mostra il messaggio di benvenuto' },
    { command: 'help', description: 'Mostra i comandi disponibili' },
    { command: 'cerca', description: 'Avvia la ricerca guidata passo-passo' },
    { command: 'annulla', description: 'Annulla la ricerca guidata in corso' }
  ];

  await telegramApi('setMyCommands', { commands });
  console.log('[telegram] Comandi bot impostati con successo');
};

const deleteWebhook = async () => {
  await telegramApi('deleteWebhook', { drop_pending_updates: false });
  console.log('[telegram] Webhook rimosso');
};

const main = async () => {
  const action = process.argv[2];

  if (!action) {
    console.log('Usage: node telegram-bot/manageTelegram.js <set-webhook|webhook-info|set-commands|delete-webhook>');
    process.exit(1);
  }

  if (action === 'set-webhook') {
    await setWebhook();
    return;
  }

  if (action === 'webhook-info') {
    await getWebhookInfo();
    return;
  }

  if (action === 'set-commands') {
    await setCommands();
    return;
  }

  if (action === 'delete-webhook') {
    await deleteWebhook();
    return;
  }

  console.log('Unknown action:', action);
  process.exit(1);
};

main().catch((error) => {
  console.error('[telegram] Errore:', error.message);
  process.exit(1);
});
