const rateLimit = require('express-rate-limit');

const extractIpFromForwarded = (forwardedHeader) => {
  if (!forwardedHeader) {
    return null;
  }

  // Example: for=203.0.113.43;proto=https;by=203.0.113.44
  const match = forwardedHeader.match(/for=([^;,$]+)/i);
  if (!match?.[1]) {
    return null;
  }

  return match[1]
    .trim()
    .replace(/^"|"$/g, '')
    .replace(/^\[|\]$/g, '');
};

const getClientIp = (req) => {
  const xForwardedFor = req.headers['x-forwarded-for'];
  if (typeof xForwardedFor === 'string' && xForwardedFor.trim()) {
    return xForwardedFor.split(',')[0].trim();
  }

  const forwarded = req.headers.forwarded;
  if (typeof forwarded === 'string' && forwarded.trim()) {
    const forwardedIp = extractIpFromForwarded(forwarded);
    if (forwardedIp) {
      return forwardedIp;
    }
  }

  return req.ip;
};

const ipKeyGenerator = (req, _res) => rateLimit.ipKeyGenerator(getClientIp(req));

const jsonRateLimitHandler = (req, res, _next, options) => {
  const rawMessage = options?.message;
  const message = typeof rawMessage === 'string'
    ? rawMessage
    : rawMessage?.message || 'Too many requests, please try again later.';

  res.status(options.statusCode).json({ message });
};

// General API rate limiter
const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // Limit each IP to 100 requests per windowMs
  message: 'Too many requests from this IP, please try again later.',
  keyGenerator: ipKeyGenerator,
  handler: jsonRateLimitHandler,
  standardHeaders: true, // Return rate limit info in the `RateLimit-*` headers
  legacyHeaders: false, // Disable the `X-RateLimit-*` headers
});

// Strict rate limiter for authentication endpoints
const authLimiter = rateLimit({
  windowMs: 60 * 1000, // 1 minute
  max: 5, // Allow up to 5 attempts per minute; block on the 6th
  message: 'Too many authentication attempts, please try again in 1 minute.',
  keyGenerator: ipKeyGenerator,
  handler: jsonRateLimitHandler,
  standardHeaders: true,
  legacyHeaders: false,
});

// Moderate rate limiter for write operations
const writeLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 30, // Limit each IP to 30 write requests per windowMs
  message: 'Too many write requests, please try again later.',
  keyGenerator: (req, res) => req.user?.userId?.toString() || ipKeyGenerator(req, res),
  handler: jsonRateLimitHandler,
  standardHeaders: true,
  legacyHeaders: false,
});

module.exports = {
  apiLimiter,
  authLimiter,
  writeLimiter
};
