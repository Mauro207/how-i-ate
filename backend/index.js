const express = require('express');
const cors = require('cors');
const dotenv = require('dotenv');
const path = require('path');
const swaggerUi = require('swagger-ui-express');
const connectDB = require('./config/database');
const swaggerSpec = require('./config/swagger');
const { apiLimiter } = require('./middleware/rateLimiter');

// Load environment variables from backend/.env regardless of current working directory
// and override shell/system values to keep local development deterministic.
dotenv.config({ path: path.join(__dirname, '.env'), override: true });

// Initialize express app
const app = express();
const PORT = process.env.PORT || 3000;

// Registra il webhook Telegram su Vercel (o qualsiasi host con BACKEND_URL configurato)
const registerTelegramWebhook = async () => {
  const token = process.env.TELEGRAM_BOT_TOKEN;
  const backendUrl = (process.env.BACKEND_URL || '').replace(/\/$/, '');

  if (!token || !backendUrl) {
    if (token) {
      console.log('[telegram] BACKEND_URL non impostata, registrazione webhook saltata');
    }
    return;
  }

  const webhookUrl = `${backendUrl}/api/telegram/webhook`;
  const body = { url: webhookUrl };

  const secret = process.env.TELEGRAM_WEBHOOK_SECRET;
  if (secret) {
    body.secret_token = secret;
  }

  try {
    const response = await fetch(`https://api.telegram.org/bot${token}/setWebhook`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body)
    });
    const data = await response.json();
    if (data.ok) {
      console.log(`[telegram] Webhook registrato: ${webhookUrl}`);
    } else {
      console.error('[telegram] Errore registrazione webhook:', data.description);
    }
  } catch (error) {
    console.error('[telegram] Registrazione webhook fallita:', error.message);
  }
};

// Connect to MongoDB
connectDB()
  .then(() => {
    app.listen(PORT, () => {
      console.log(`Server is running on port ${PORT}`);
    });
    registerTelegramWebhook();
  })
  .catch((error) => {
    console.error('Failed to start server:', error.message);
    process.exit(1);
  });

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Apply general rate limiting to all API routes
app.use('/api/', apiLimiter);

// Import routes
const authRoutes = require('./routes/auth');
const restaurantRoutes = require('./routes/restaurants');
const reviewRoutes = require('./routes/reviews');
const suggestionRoutes = require('./routes/suggestions');
const notificationRoutes = require('./routes/notifications');
const telegramRoutes = process.env.TELEGRAM_BOT_TOKEN ? require('./routes/telegram') : null;

// Routes
app.get('/', (req, res) => {
  res.json({ message: 'Welcome to How I Ate API' });
});

// Swagger API Documentation
app.use('/api', swaggerUi.serve);
app.get('/api', swaggerUi.setup(swaggerSpec, {
  customCss: '.swagger-ui .topbar { display: none }',
  customSiteTitle: 'How I Ate API Documentation'
}));

app.get('/api/health', (req, res) => {
  res.json({ status: 'OK', timestamp: new Date().toISOString() });
});

// API Routes
app.use('/api/auth', authRoutes);
app.use('/api/restaurants', restaurantRoutes);
app.use('/api/reviews', reviewRoutes);
app.use('/api/suggestions', suggestionRoutes);
app.use('/api/notifications', notificationRoutes);

if (telegramRoutes) {
  app.use('/api/telegram', telegramRoutes);
  console.log('[telegram] Route webhook attiva su /api/telegram/webhook');
}

// Error handling middleware
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ 
    message: 'Something went wrong!', 
    error: process.env.NODE_ENV === 'development' ? err.message : undefined 
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({ message: 'Route not found' });
});

module.exports = app;
