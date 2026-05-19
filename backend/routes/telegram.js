const express = require('express');
const { processTelegramUpdate } = require('../telegram-bot/index');

const router = express.Router();

/**
 * POST /api/telegram/webhook
 *
 * Riceve gli aggiornamenti da Telegram e li passa al bot.
 * Telegram invia l'header X-Telegram-Bot-Api-Secret-Token se configurato.
 */
router.post('/webhook', async (req, res) => {
  const secret = process.env.TELEGRAM_WEBHOOK_SECRET;

  if (secret) {
    const incoming = req.headers['x-telegram-bot-api-secret-token'];
    if (incoming !== secret) {
      return res.sendStatus(403);
    }
  }

  try {
    await processTelegramUpdate(req.body);
    return res.sendStatus(200);
  } catch (error) {
    console.error('[telegram-webhook] Error:', error.message);
    // Return 200 to avoid repeated retries for the same update.
    return res.sendStatus(200);
  }
});

module.exports = router;
