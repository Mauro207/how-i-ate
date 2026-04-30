const express = require('express');
const PushSubscription = require('../models/PushSubscription');
const { authenticate } = require('../middleware/auth');
const { webpush, getPushConfig } = require('../config/push');

const router = express.Router();

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

    const { subscription } = req.body;

    if (!subscription || !subscription.endpoint || !subscription.keys?.p256dh || !subscription.keys?.auth) {
      return res.status(400).json({ message: 'Dati di sottoscrizione non validi' });
    }

    await PushSubscription.findOneAndUpdate(
      { 'subscription.endpoint': subscription.endpoint },
      { user: req.user.userId, subscription },
      { upsert: true, new: true }
    );

    res.status(201).json({ message: 'Sottoscrizione salvata' });
  } catch (error) {
    res.status(500).json({ message: 'Errore durante il salvataggio della sottoscrizione', error: error.message });
  }
});

// POST /api/notifications/test — send a test push notification only to the current user
router.post('/test', authenticate, async (req, res) => {
  try {
    const { pushConfigured } = getPushConfig();
    if (!pushConfigured) {
      return res.status(503).json({ message: 'Push notifications not configured' });
    }

    const subscriptions = await PushSubscription.find({ user: req.user.userId });
    if (!subscriptions.length) {
      return res.status(404).json({ message: 'Nessuna sottoscrizione attiva trovata per questo utente' });
    }

    const payload = JSON.stringify({
      title: 'How I Ate — Notifica di prova',
      body: 'Le notifiche funzionano correttamente! 🎉',
      url: '/'
    });

    const results = await Promise.allSettled(
      subscriptions.map(doc => webpush.sendNotification(doc.subscription, payload))
    );

    const failed = results.filter(r => r.status === 'rejected');
    if (failed.length === subscriptions.length) {
      return res.status(500).json({ message: 'Invio notifica di prova fallito' });
    }

    res.json({ message: 'Notifica di prova inviata' });
  } catch (error) {
    res.status(500).json({ message: 'Errore durante l\'invio della notifica di prova', error: error.message });
  }
});

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

module.exports = router;
