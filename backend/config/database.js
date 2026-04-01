const mongoose = require('mongoose');

let cached = global.mongoose || { conn: null, promise: null };

const connectDB = async () => {
  const mongoUri = process.env.MONGODB_URI || process.env.DATABASE_URL;

  // Return cached connection if exists
  if (cached.conn) {
    return cached.conn;
  }

  if (!mongoUri) {
    throw new Error('Missing MongoDB connection string. Set MONGODB_URI or DATABASE_URL in backend/.env.');
  }

  if (!cached.promise) {
    cached.promise = mongoose.connect(mongoUri, {
      maxPoolSize: 10,
      minPoolSize: 2,
      serverSelectionTimeoutMS: 5000,
      socketTimeoutMS: 45000,
    }).then(mongoose => {
      console.log('MongoDB connected successfully');
      return mongoose;
    }).catch(error => {
      console.error('MongoDB connection error:', error);
      throw error;
    });
  }

  try {
    cached.conn = await cached.promise;
  } catch (error) {
    cached.promise = null;
    throw error;
  }

  global.mongoose = cached;
  return cached.conn;
};

module.exports = connectDB;
