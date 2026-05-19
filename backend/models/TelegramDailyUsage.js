const mongoose = require('mongoose');

const telegramDailyUsageSchema = new mongoose.Schema({
  telegramUserId: {
    type: String,
    required: true,
    trim: true
  },
  dateKey: {
    type: String,
    required: true,
    trim: true
  },
  requestCount: {
    type: Number,
    required: true,
    default: 0,
    min: 0
  }
}, {
  timestamps: true
});

telegramDailyUsageSchema.index({ telegramUserId: 1, dateKey: 1 }, { unique: true });

module.exports = mongoose.model('TelegramDailyUsage', telegramDailyUsageSchema);
