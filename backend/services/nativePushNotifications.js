const NativePushDevice = require('../models/NativePushDevice');
const { provider, getAPNSConfig } = require('../config/apns');

const REMOVABLE_FAILURE_STATUSES = new Set([400, 410]);
const REMOVABLE_FAILURE_REASONS = new Set([
  'BadDeviceToken',
  'Unregistered',
  'DeviceTokenNotForTopic'
]);

const summarizeResults = (results) => results.reduce((summary, result) => ({
  sent: summary.sent + (result.sent ? 1 : 0),
  failed: summary.failed + (!result.sent ? 1 : 0),
  removed: summary.removed + (result.removed ? 1 : 0)
}), { sent: 0, failed: 0, removed: 0 });

const buildNotification = (payload, topic) => {
  const apnsNotification = {
    topic,
    pushType: 'alert',
    expiry: Math.floor(Date.now() / 1000) + 3600,
    sound: 'default',
    badge: 1,
    alert: {
      title: payload.title || 'How I Ate',
      body: payload.body || ''
    },
    payload: {
      url: payload.url || '/',
      tag: payload.tag || null,
      actions: payload.actions || []
    }
  };

  return apnsNotification;
};

const shouldRemoveToken = (failure) => {
  const status = failure?.status;
  const reason = failure?.response?.reason;
  return REMOVABLE_FAILURE_STATUSES.has(status) || REMOVABLE_FAILURE_REASONS.has(reason);
};

const sendNativePushToDevices = async (devices, payload) => {
  const { apnsConfigured, bundleId } = getAPNSConfig();
  if (!apnsConfigured || !provider) {
    return { sent: 0, failed: 0, removed: 0, total: 0, configured: false };
  }

  if (!devices.length) {
    return { sent: 0, failed: 0, removed: 0, total: 0, configured: true };
  }

  const tokenToDeviceId = new Map(devices.map((device) => [device.deviceToken, device._id]));
  const tokens = devices.map((device) => device.deviceToken);
  const notification = buildNotification(payload, bundleId);

  let response;
  try {
    response = await provider.send(notification, tokens);
  } catch (error) {
    console.error('[apns] Errore invio batch:', error.message);
    return {
      sent: 0,
      failed: tokens.length,
      removed: 0,
      total: tokens.length,
      configured: true
    };
  }

  const removableIds = response.failed
    .filter(shouldRemoveToken)
    .map((failure) => tokenToDeviceId.get(failure.device))
    .filter(Boolean);

  if (removableIds.length) {
    await NativePushDevice.deleteMany({ _id: { $in: removableIds } });
  }

  const summary = summarizeResults([
    ...response.sent.map(() => ({ sent: true, removed: false })),
    ...response.failed.map((failure) => ({ sent: false, removed: shouldRemoveToken(failure) }))
  ]);

  return {
    ...summary,
    total: tokens.length,
    configured: true
  };
};

const sendNativeToAll = async (payload) => {
  const devices = await NativePushDevice.find({ provider: 'apns' });
  const summary = await sendNativePushToDevices(devices, payload);
  console.log(`[apns] Notifiche native inviate: ${summary.sent}/${summary.total} (rimosse: ${summary.removed})`);
  return summary;
};

const sendNativeToUser = async (userId, payload) => {
  const devices = await NativePushDevice.find({ user: userId, provider: 'apns' });
  return sendNativePushToDevices(devices, payload);
};

const sendNativeToUsers = async (userIds, payload) => {
  const devices = await NativePushDevice.find({ user: { $in: userIds }, provider: 'apns' });
  return sendNativePushToDevices(devices, payload);
};

module.exports = {
  sendNativeToAll,
  sendNativeToUser,
  sendNativeToUsers
};
