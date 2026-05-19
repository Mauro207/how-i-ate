const connectDB = require('../config/database');
const TelegramDailyUsage = require('../models/TelegramDailyUsage');

const MAX_DAILY_REQUESTS = 10;

const toDateKey = (date) => {
  const year = date.getUTCFullYear();
  const month = String(date.getUTCMonth() + 1).padStart(2, '0');
  const day = String(date.getUTCDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
};

const checkAndConsumeDailyRequest = async ({ telegramUserId }) => {
  if (!telegramUserId) {
    throw new Error('telegramUserId is required');
  }

  await connectDB();

  const now = new Date();
  const dateKey = toDateKey(now);

  try {
    const usage = await TelegramDailyUsage.findOneAndUpdate(
      {
        telegramUserId,
        dateKey,
        requestCount: { $lt: MAX_DAILY_REQUESTS }
      },
      {
        $inc: { requestCount: 1 },
        $set: { updatedAt: now },
        $setOnInsert: {
          telegramUserId,
          dateKey,
          createdAt: now
        }
      },
      {
        new: true,
        upsert: true,
        setDefaultsOnInsert: true
      }
    );

    return {
      allowed: true,
      used: usage.requestCount,
      remaining: Math.max(MAX_DAILY_REQUESTS - usage.requestCount, 0),
      max: MAX_DAILY_REQUESTS
    };
  } catch (error) {
    if (error.code !== 11000) {
      throw error;
    }
  }

  const current = await TelegramDailyUsage.findOne({ telegramUserId, dateKey }).lean();
  const used = current?.requestCount || MAX_DAILY_REQUESTS;

  return {
    allowed: false,
    used,
    remaining: 0,
    max: MAX_DAILY_REQUESTS
  };
};

module.exports = {
  MAX_DAILY_REQUESTS,
  checkAndConsumeDailyRequest
};
