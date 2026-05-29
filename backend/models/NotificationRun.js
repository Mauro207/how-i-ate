const mongoose = require('mongoose');

const notificationRunSchema = new mongoose.Schema({
  key: {
    type: String,
    required: true,
    unique: true,
    trim: true
  },
  type: {
    type: String,
    required: true,
    trim: true
  },
  sent: {
    type: Number,
    default: 0
  },
  failed: {
    type: Number,
    default: 0
  },
  removed: {
    type: Number,
    default: 0
  }
}, { timestamps: true });

module.exports = mongoose.model('NotificationRun', notificationRunSchema);
