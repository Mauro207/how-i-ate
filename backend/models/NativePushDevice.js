const mongoose = require('mongoose');

const nativePushDeviceSchema = new mongoose.Schema({
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true
  },
  provider: {
    type: String,
    enum: ['apns'],
    default: 'apns'
  },
  deviceToken: {
    type: String,
    required: true,
    unique: true,
    trim: true
  },
  client: {
    platform: { type: String, default: 'ios' },
    appVersion: { type: String, default: 'unknown' },
    buildNumber: { type: String, default: 'unknown' },
    bundleId: { type: String, default: 'unknown' }
  },
  lastSeenAt: {
    type: Date,
    default: Date.now
  }
}, { timestamps: true });

nativePushDeviceSchema.index({ user: 1, provider: 1 });

module.exports = mongoose.model('NativePushDevice', nativePushDeviceSchema);
