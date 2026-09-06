const crypto = require('node:crypto');
const User = require('../models/User');
const { sendPushToUsers } = require('./pushNotifications');

const isInvitationToken = (token) => typeof token === 'string' && /^[a-f0-9]{64}$/.test(token);

const findInviter = async (token) => {
  if (!isInvitationToken(token)) return null;
  return User.findOne({ invitationToken: token }).select('_id username displayName');
};

const notifyRegistration = async (user) => {
  const admins = await User.find({ role: { $in: ['admin', 'superadmin'] } }).select('_id');
  if (!admins.length) return;
  await sendPushToUsers(admins.map(admin => admin._id), {
    title: 'How I Ate',
    body: `${user.displayName || user.username} si è registrato`,
    url: `/profile/${user._id}`,
    tag: `registration-${user._id}`
  });
};

const getInvitation = async (req, res) => {
  try {
    // Only the first concurrent request wins; subsequent requests read that same link.
    const user = await User.findOneAndUpdate(
      { _id: req.user.userId, invitationToken: { $exists: false } },
      { $set: { invitationToken: crypto.randomBytes(32).toString('hex') } },
      { new: true }
    ).select('+invitationToken') || await User.findById(req.user.userId).select('+invitationToken');
    if (!user) return res.status(404).json({ message: 'Utente non trovato.' });
    return res.json({ token: user.invitationToken, dismissed: user.invitationPromptDismissed });
  } catch (error) {
    return res.status(500).json({ message: 'Impossibile creare il link di invito. Riprova.' });
  }
};

const dismissPrompt = async (req, res) => {
  try {
    await User.updateOne({ _id: req.user.userId }, { $set: { invitationPromptDismissed: true } });
    return res.json({ dismissed: true });
  } catch (error) {
    return res.status(500).json({ message: 'Impossibile salvare la preferenza. Riprova.' });
  }
};

const previewInvitation = async (req, res) => {
  try {
    const inviter = await findInviter(req.params.token);
    if (!inviter) return res.status(404).json({ message: 'Questo invito non è valido o non è più disponibile.' });
    return res.json({ inviter: { name: inviter.displayName || inviter.username } });
  } catch (error) {
    return res.status(500).json({ message: 'Impossibile verificare l’invito. Riprova.' });
  }
};

module.exports = { findInviter, notifyRegistration, getInvitation, dismissPrompt, previewInvitation };
