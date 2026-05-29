const express = require('express');
const PushSubscription = require('../models/PushSubscription');
const NativePushDevice = require('../models/NativePushDevice');
const NotificationRun = require('../models/NotificationRun');
const { authenticate } = require('../middleware/auth');
const { getPushConfig } = require('../config/push');
const { getAPNSConfig } = require('../config/apns');
const { sendPushToAll, sendPushToUser } = require('../services/pushNotifications');

const router = express.Router();
const ROME_TIMEZONE = 'Europe/Rome';

// GET /api/notifications/vapid-public-key — public, returns VAPID public key for frontend subscription
router.get('/vapid-public-key', (req, res) => {
  const { pushConfigured, vapidPublicKey } = getPushConfig();
  if (!pushConfigured || !vapidPublicKey) {
    return res.status(503).json({ message: 'Push notifications not configured' });
  }
  res.json({ publicKey: vapidPublicKey });
});

// POST /api/notifications/subscribe — save push subscription for authenticated user
router.post('/subscribe', authenticate, async (req, res) => {
  try {
    const { pushConfigured } = getPushConfig();
    if (!pushConfigured) {
      return res.status(503).json({ message: 'Push notifications not configured' });
    }

    const { subscription, client } = req.body;

    if (!subscription || !subscription.endpoint || !subscription.keys?.p256dh || !subscription.keys?.auth) {
      return res.status(400).json({ message: 'Dati di sottoscrizione non validi' });
    }

    await PushSubscription.findOneAndUpdate(
      { 'subscription.endpoint': subscription.endpoint },
      {
        user: req.user.userId,
        subscription,
        client: {
          browser: client?.browser || 'unknown',
          platform: client?.platform || 'unknown',
          standalone: Boolean(client?.standalone)
        },
        lastSeenAt: new Date()
      },
      { upsert: true, new: true }
    );

    res.status(201).json({ message: 'Sottoscrizione salvata' });
  } catch (error) {
    res.status(500).json({ message: 'Errore durante il salvataggio della sottoscrizione', error: error.message });
  }
});

// POST /api/notifications/native/subscribe — save APNs device token for authenticated user
router.post('/native/subscribe', authenticate, async (req, res) => {
  try {
    const { apnsConfigured } = getAPNSConfig();
    if (!apnsConfigured) {
      return res.status(503).json({ message: 'APNs non configurato sul backend' });
    }

    const { deviceToken, provider, client } = req.body;
    const normalizedProvider = (provider || 'apns').toString().toLowerCase();
    const normalizedToken = (deviceToken || '').toString().trim().toLowerCase();

    if (normalizedProvider !== 'apns') {
      return res.status(400).json({ message: 'Provider non supportato. Usa apns.' });
    }

    if (!/^[0-9a-f]{32,}$/.test(normalizedToken)) {
      return res.status(400).json({ message: 'Token dispositivo non valido' });
    }

    await NativePushDevice.findOneAndUpdate(
      { deviceToken: normalizedToken },
      {
        user: req.user.userId,
        provider: 'apns',
        deviceToken: normalizedToken,
        client: {
          platform: client?.platform || 'ios',
          appVersion: client?.appVersion || 'unknown',
          buildNumber: client?.buildNumber || 'unknown',
          bundleId: client?.bundleId || 'unknown'
        },
        lastSeenAt: new Date()
      },
      { upsert: true, new: true }
    );

    res.status(201).json({ message: 'Dispositivo APNs registrato' });
  } catch (error) {
    res.status(500).json({ message: 'Errore durante la registrazione APNs', error: error.message });
  }
});

// POST /api/notifications/test — send a test push notification only to the current user
router.post('/test', authenticate, async (req, res) => {
  try {
    const summary = await sendPushToUser(req.user.userId, {
      title: 'How I Ate — Notifica di prova',
      body: 'Le notifiche funzionano correttamente!',
      url: '/',
      tag: 'test-notification'
    });

    if (!summary.configured) {
      return res.status(503).json({ message: 'Nessun provider push configurato (Web Push o APNs)' });
    }

    if (!summary.total) {
      return res.status(404).json({ message: 'Nessuna sottoscrizione attiva trovata per questo utente' });
    }
    if (!summary.sent) {
      return res.status(500).json({ message: 'Invio notifica di prova fallito' });
    }

    res.json({ message: 'Notifica di prova inviata', summary });
  } catch (error) {
    res.status(500).json({ message: 'Errore durante l\'invio della notifica di prova', error: error.message });
  }
});

const getRomeParts = (date = new Date()) => {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: ROME_TIMEZONE,
    weekday: 'short',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false
  }).formatToParts(date).reduce((acc, part) => {
    acc[part.type] = part.value;
    return acc;
  }, {});

  return {
    weekday: parts.weekday,
    dateKey: `${parts.year}-${parts.month}-${parts.day}`,
    hour: Number(parts.hour),
    minute: Number(parts.minute)
  };
};

const isWeeklyReminderWindow = (date = new Date()) => {
  const rome = getRomeParts(date);
  return rome.weekday === 'Sun' &&
    (rome.hour === 21 || rome.hour === 22) &&
    rome.minute >= 20 &&
    rome.minute <= 45;
};

const authorizeCron = (req) => {
  const configuredSecret = process.env.CRON_SECRET;
  if (!configuredSecret) return true;

  const authHeader = req.get('authorization') || '';
  const headerSecret = req.get('x-cron-secret');
  const querySecret = req.query.secret;

  return authHeader === `Bearer ${configuredSecret}` ||
    headerSecret === configuredSecret ||
    querySecret === configuredSecret;
};

// GET/POST /api/notifications/weekly-review-reminder — scheduled weekly push reminder
const weeklyReviewReminder = async (req, res) => {
  try {
    if (!authorizeCron(req)) {
      return res.status(401).json({ message: 'Unauthorized' });
    }

    const now = new Date();
    const force = req.query.force === 'true' || req.body?.force === true;
    const rome = getRomeParts(now);

    if (!force && !isWeeklyReminderWindow(now)) {
      return res.json({
        message: 'Fuori dalla finestra del reminder settimanale',
        skipped: true,
        rome
      });
    }

    const runKey = `weekly-review-reminder:${rome.dateKey}`;
    const existingRun = await NotificationRun.findOne({ key: runKey });
    if (existingRun && !force) {
      return res.json({ message: 'Reminder gia inviato questa domenica', skipped: true, run: existingRun });
    }

    const run = existingRun || await NotificationRun.create({ key: runKey, type: 'weekly-review-reminder' });

    const summary = await sendPushToAll({
      title: 'Com’è andata a cena?',
      body: 'Hai provato un posto questa settimana? Lascia una recensione su How I Ate.',
      url: '/restaurants',
      tag: runKey,
      requireInteraction: false,
      actions: [
        { action: 'review', title: 'Recensisci' }
      ]
    });

    run.sent = summary.sent;
    run.failed = summary.failed;
    run.removed = summary.removed;
    await run.save();

    res.json({ message: 'Reminder settimanale inviato', summary, runKey });
  } catch (error) {
    res.status(500).json({ message: 'Errore durante il reminder settimanale', error: error.message });
  }
};

router.get('/weekly-review-reminder', weeklyReviewReminder);
router.post('/weekly-review-reminder', weeklyReviewReminder);

// DELETE /api/notifications/unsubscribe — remove push subscription for authenticated user
router.delete('/unsubscribe', authenticate, async (req, res) => {
  try {
    const { pushConfigured } = getPushConfig();
    if (!pushConfigured) {
      return res.status(503).json({ message: 'Push notifications not configured' });
    }

    const { endpoint } = req.body;

    if (endpoint) {
      await PushSubscription.deleteOne({ user: req.user.userId, 'subscription.endpoint': endpoint });
    } else {
      await PushSubscription.deleteMany({ user: req.user.userId });
    }

    res.json({ message: 'Sottoscrizione rimossa' });
  } catch (error) {
    res.status(500).json({ message: 'Errore durante la rimozione della sottoscrizione', error: error.message });
  }
});

// DELETE /api/notifications/native/unsubscribe — remove APNs device token for authenticated user
router.delete('/native/unsubscribe', authenticate, async (req, res) => {
  try {
    const { apnsConfigured } = getAPNSConfig();
    if (!apnsConfigured) {
      return res.status(503).json({ message: 'APNs non configurato sul backend' });
    }

    const { deviceToken } = req.body || {};
    const normalizedToken = typeof deviceToken === 'string' ? deviceToken.trim().toLowerCase() : '';

    if (normalizedToken) {
      await NativePushDevice.deleteOne({ user: req.user.userId, provider: 'apns', deviceToken: normalizedToken });
    } else {
      await NativePushDevice.deleteMany({ user: req.user.userId, provider: 'apns' });
    }

    res.json({ message: 'Dispositivo APNs rimosso' });
  } catch (error) {
    res.status(500).json({ message: 'Errore durante la rimozione dispositivo APNs', error: error.message });
  }
});

module.exports = router;
