
const express = require('express');
const Suggestion = require('../models/Suggestion');
const Restaurant = require('../models/Restaurant');
const User = require('../models/User');
const PushSubscription = require('../models/PushSubscription');
const { webpush, getPushConfig } = require('../config/push');
const Review = require('../models/Review');
const { authenticate, authorize } = require('../middleware/auth');
const { writeLimiter } = require('../middleware/rateLimiter');

const router = express.Router();

// Submit a suggestion (all authenticated users)
router.post('/', writeLimiter, authenticate, async (req, res) => {
  try {
    const { name, description, address, cuisine, review } = req.body;

    if (!name) {
      return res.status(400).json({ message: 'Restaurant name is required' });
    }
    // Controllo presenza e validità della recensione
    if (!review || typeof review !== 'object') {
      return res.status(400).json({ message: 'Review is required' });
    }
    const { serviceRating, priceRating, menuRating, comment } = review;
    if (
      serviceRating == null || priceRating == null || menuRating == null ||
      typeof comment !== 'string' || comment.trim().length < 5
    ) {
      return res.status(400).json({ message: 'All review fields are required and valid' });
    }

    // Crea il suggerimento
    const suggestion = new Suggestion({
      name,
      description,
      address,
      cuisine,
      suggestedBy: req.user.userId
    });
    await suggestion.save();
    await suggestion.populate('suggestedBy', 'username email displayName');

    // Crea la recensione associata al suggerimento (campo restaurant = suggestion._id, tipo ObjectId)
    const reviewDoc = new Review({
      restaurant: suggestion._id, // NOTA: qui usiamo il suggestion._id come riferimento temporaneo
      user: req.user.userId,
      serviceRating,
      priceRating,
      menuRating,
      comment
    });
    await reviewDoc.save();

    // INVIO NOTIFICA SOLO AGLI ADMIN/SUPERADMIN
    const { pushConfigured } = getPushConfig();
    if (pushConfigured) {
      const admins = await User.find({ role: { $in: ['admin', 'superadmin'] } }, '_id');
      const adminIds = admins.map(u => u._id);
      const adminSubs = await PushSubscription.find({ user: { $in: adminIds } });
      const notificationPayload = JSON.stringify({
        title: 'Nuova segnalazione',
        body: `È stata aggiunta una nuova segnalazione: ${name}`,
        url: '/admin/suggestions'
      });
      for (const sub of adminSubs) {
        try {
          await webpush.sendNotification(sub.subscription, notificationPayload);
        } catch (err) {}
      }
    }

    res.status(201).json({
      message: 'Suggestion and review submitted successfully',
      suggestion,
      review: reviewDoc
    });
  } catch (error) {
    res.status(500).json({
      message: 'Error submitting suggestion and review',
      error: error.message
    });
  }
});

// Get all pending suggestions (admin/superadmin only)
router.get('/', authenticate, authorize('admin', 'superadmin'), async (req, res) => {
  try {
    const suggestions = await Suggestion.find({ status: 'pending' })
      .populate('suggestedBy', 'username email displayName')
      .sort({ createdAt: -1 });

    res.json({
      count: suggestions.length,
      suggestions
    });
  } catch (error) {
    res.status(500).json({
      message: 'Error fetching suggestions',
      error: error.message
    });
  }
});

// Approve a suggestion (admin/superadmin only) - creates a restaurant from it
router.put('/:id/approve', writeLimiter, authenticate, authorize('admin', 'superadmin'), async (req, res) => {
  try {
    const suggestion = await Suggestion.findById(req.params.id);

    if (!suggestion) {
      return res.status(404).json({ message: 'Suggestion not found' });
    }

    const restaurant = new Restaurant({
      name: suggestion.name,
      description: suggestion.description,
      address: suggestion.address,
      cuisine: suggestion.cuisine,
      createdBy: req.user.userId
    });

    await restaurant.save();
    await restaurant.populate('createdBy', 'username email displayName');

    // Invia notifica push a tutti gli iscritti, come nella creazione admin di un nuovo luogo
    const { pushConfigured } = getPushConfig();
    if (pushConfigured) {
      PushSubscription.find().then(async subscriptions => {
        if (!subscriptions.length) return;

        const payload = JSON.stringify({
          title: 'Nuovo luogo aggiunto!',
          body: `Ora puoi recensire "${restaurant.name}"!`,
          url: `/restaurants/${restaurant._id}`
        });

        console.log(`[push] Invio notifica approvazione per "${restaurant.name}" a ${subscriptions.length} subscriber(s)`);

        const results = await Promise.allSettled(
          subscriptions.map(sub =>
            webpush.sendNotification(sub.subscription, payload).catch(async err => {
              const shouldRemove =
                err.statusCode === 410 ||
                err.statusCode === 404 ||
                err.statusCode === 400 ||
                (err.message && err.message.includes('unexpected response'));

              if (shouldRemove) {
                console.log(`[push] Subscription non valida rimossa (${err.statusCode ?? 'unknown'}): ${sub.subscription.endpoint}`);
                await PushSubscription.deleteOne({ _id: sub._id });
              } else {
                console.error(`[push] Errore invio notifica a ${sub.subscription.endpoint}:`, err.statusCode, err.message);
              }
            })
          )
        );

        const sent = results.filter(r => r.status === 'fulfilled').length;
        console.log(`[push] Notifiche inviate: ${sent}/${subscriptions.length}`);
      }).catch(err => console.error('[push] Errore recupero subscriptions:', err.message));
    } else {
      console.log('[push] VAPID non configurato, notifiche non inviate.');
    }

    await Suggestion.findByIdAndDelete(req.params.id);

    res.json({
      message: 'Suggestion approved and restaurant created',
      restaurant
    });
  } catch (error) {
    if (error.kind === 'ObjectId') {
      return res.status(404).json({ message: 'Suggestion not found' });
    }
    res.status(500).json({
      message: 'Error approving suggestion',
      error: error.message
    });
  }
});

// Reject a suggestion (admin/superadmin only) - deletes it
router.delete('/:id', writeLimiter, authenticate, authorize('admin', 'superadmin'), async (req, res) => {
  try {
    // Cancella la recensione associata (restaurant = suggestion._id)
    await Review.deleteMany({ restaurant: req.params.id });
    const deleted = await Suggestion.findByIdAndDelete(req.params.id);

    if (!deleted) {
      return res.status(404).json({ message: 'Suggestion not found' });
    }

    res.json({ message: 'Suggestion and review rejected' });
  } catch (error) {
    if (error.kind === 'ObjectId') {
      return res.status(404).json({ message: 'Suggestion not found' });
    }
    res.status(500).json({
      message: 'Error rejecting suggestion and review',
      error: error.message
    });
  }
});

module.exports = router;
