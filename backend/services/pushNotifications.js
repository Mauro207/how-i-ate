const PushSubscription = require('../models/PushSubscription');
const { webpush, getPushConfig } = require('../config/push');
const {
  sendNativeToAll,
  sendNativeToUser,
  sendNativeToUsers
} = require('./nativePushNotifications');

const INVALID_SUBSCRIPTION_STATUS_CODES = new Set([400, 404, 410]);

const shouldRemoveSubscription = (error) => (
  INVALID_SUBSCRIPTION_STATUS_CODES.has(error?.statusCode) ||
  (error?.message && error.message.includes('unexpected response'))
);

const normalizePayload = (payload) => JSON.stringify({
  title: payload.title || 'How I Ate',
  body: payload.body || '',
  url: payload.url || '/',
  tag: payload.tag,
  requireInteraction: Boolean(payload.requireInteraction),
  actions: payload.actions || []
});

const sendPushNotification = async (subscriptionDoc, payload) => {
  try {
    await webpush.sendNotification(subscriptionDoc.subscription, normalizePayload(payload));
    return { sent: true, removed: false };
  } catch (error) {
    if (shouldRemoveSubscription(error)) {
      await PushSubscription.deleteOne({ _id: subscriptionDoc._id });
      console.log(`[push] Subscription non valida rimossa (${error.statusCode ?? 'unknown'}): ${subscriptionDoc.subscription.endpoint}`);
      return { sent: false, removed: true };
    }

    console.error('[push] Errore invio notifica:', error.statusCode, error.message);
    return { sent: false, removed: false };
  }
};

const summarizeResults = (results) => results.reduce((summary, result) => ({
  sent: summary.sent + (result.sent ? 1 : 0),
  failed: summary.failed + (!result.sent ? 1 : 0),
  removed: summary.removed + (result.removed ? 1 : 0)
}), { sent: 0, failed: 0, removed: 0 });

const sendPushToSubscriptions = async (subscriptions, payload) => {
  const { pushConfigured } = getPushConfig();
  if (!pushConfigured) {
    console.log('[push] VAPID non configurato, notifiche non inviate.');
    return { sent: 0, failed: 0, removed: 0, total: 0, configured: false };
  }

  if (!subscriptions.length) {
    return { sent: 0, failed: 0, removed: 0, total: 0, configured: true };
  }

  const results = await Promise.all(subscriptions.map((subscription) => sendPushNotification(subscription, payload)));
  return {
    ...summarizeResults(results),
    total: subscriptions.length,
    configured: true
  };
};

const sendPushToAll = async (payload) => {
  const subscriptions = await PushSubscription.find();
  const [webSummary, nativeSummary] = await Promise.all([
    sendPushToSubscriptions(subscriptions, payload),
    sendNativeToAll(payload)
  ]);

  const summary = {
    sent: webSummary.sent + nativeSummary.sent,
    failed: webSummary.failed + nativeSummary.failed,
    removed: webSummary.removed + nativeSummary.removed,
    total: webSummary.total + nativeSummary.total,
    configured: webSummary.configured || nativeSummary.configured,
    channels: {
      web: webSummary,
      native: nativeSummary
    }
  };

  console.log(`[push] Notifiche inviate: ${summary.sent}/${summary.total} (rimosse: ${summary.removed})`);
  return summary;
};

const sendPushToUser = async (userId, payload) => {
  const subscriptions = await PushSubscription.find({ user: userId });
  const [webSummary, nativeSummary] = await Promise.all([
    sendPushToSubscriptions(subscriptions, payload),
    sendNativeToUser(userId, payload)
  ]);

  return {
    sent: webSummary.sent + nativeSummary.sent,
    failed: webSummary.failed + nativeSummary.failed,
    removed: webSummary.removed + nativeSummary.removed,
    total: webSummary.total + nativeSummary.total,
    configured: webSummary.configured || nativeSummary.configured,
    channels: {
      web: webSummary,
      native: nativeSummary
    }
  };
};

const sendPushToUsers = async (userIds, payload) => {
  const subscriptions = await PushSubscription.find({ user: { $in: userIds } });
  const [webSummary, nativeSummary] = await Promise.all([
    sendPushToSubscriptions(subscriptions, payload),
    sendNativeToUsers(userIds, payload)
  ]);

  return {
    sent: webSummary.sent + nativeSummary.sent,
    failed: webSummary.failed + nativeSummary.failed,
    removed: webSummary.removed + nativeSummary.removed,
    total: webSummary.total + nativeSummary.total,
    configured: webSummary.configured || nativeSummary.configured,
    channels: {
      web: webSummary,
      native: nativeSummary
    }
  };
};

module.exports = {
  sendPushToAll,
  sendPushToUser,
  sendPushToUsers
};
