const express = require('express');
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const { authenticate, authorize } = require('../middleware/auth');
const { authLimiter, writeLimiter } = require('../middleware/rateLimiter');

const router = express.Router();

// Cookie configuration constants
const COOKIE_MAX_AGE = 90 * 24 * 60 * 60 * 1000; // 90 days in milliseconds

// Generate JWT token
const generateToken = (userId) => {
  return jwt.sign(
    { userId },
    process.env.JWT_SECRET,
    { expiresIn: process.env.JWT_EXPIRES_IN || '90d' }
  );
};

// Get cookie options based on environment
const getCookieOptions = () => {
  const isProduction = process.env.NODE_ENV === 'production';
  
  // Note: CSRF protection is provided by the sameSite attribute:
  // - 'lax' in development: Prevents cookies from being sent in cross-site requests
  // - 'none' in production: Required for cross-domain cookies, but secure flag ensures HTTPS
  // Additional CSRF token not needed as API uses JWT authentication without session state
  return {
    httpOnly: true,
    secure: isProduction,
    sameSite: isProduction ? 'none' : 'lax',
    maxAge: COOKIE_MAX_AGE
  };
};

/**
 * @swagger
 * /api/auth/register:
 *   post:
 *     summary: Register a new user
 *     tags: [Authentication]
 *     security: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - username
 *               - email
 *               - password
 *             properties:
 *               username:
 *                 type: string
 *                 minLength: 3
 *               email:
 *                 type: string
 *                 format: email
 *               password:
 *                 type: string
 *                 minLength: 6
 *     responses:
 *       201:
 *         description: User registered successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                 token:
 *                   type: string
 *                 user:
 *                   $ref: '#/components/schemas/User'
 *       400:
 *         description: Invalid input or user already exists
 */
// Register new user - Apply strict rate limiting
router.post('/register', authLimiter, async (req, res) => {
  try {
    const { username, email, password } = req.body;
    
    // Validate input
    if (!username || !email || !password) {
      return res.status(400).json({ 
        message: 'Username, email, and password are required' 
      });
    }
    
    // Check if user already exists
    const existingUser = await User.findOne({ 
      $or: [{ email }, { username }] 
    });
    
    if (existingUser) {
      return res.status(400).json({ 
        message: 'User with this email or username already exists' 
      });
    }
    
    // Create new user with 'user' role by default
    const user = new User({
      username,
      email,
      password,
      role: 'user'
    });
    
    await user.save();
    
    const token = generateToken(user._id);
    
    // Set HTTP-only cookie
    res.cookie('jwt', token, getCookieOptions());
    
    res.status(201).json({
      message: 'User registered successfully',
      token,
      user: {
        id: user._id,
        username: user.username,
        displayName: user.displayName,
        email: user.email,
        role: user.role
      }
    });
  } catch (error) {
    if (error.code === 11000) {
      return res.status(400).json({ 
        message: 'User with this email or username already exists' 
      });
    }
    res.status(500).json({ 
      message: 'Error registering user', 
      error: error.message 
    });
  }
});

/**
 * @swagger
 * /api/auth/login:
 *   post:
 *     summary: Login user
 *     tags: [Authentication]
 *     security: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - email
 *               - password
 *             properties:
 *               email:
 *                 type: string
 *                 format: email
 *               password:
 *                 type: string
 *     responses:
 *       200:
 *         description: Login successful
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                 token:
 *                   type: string
 *                 user:
 *                   $ref: '#/components/schemas/User'
 *       401:
 *         description: Invalid credentials
 */
// Login user - Apply strict rate limiting
router.post('/login', authLimiter, async (req, res) => {
  try {
    const { email, password } = req.body;
    
    // Validate input
    if (!email || !password) {
      return res.status(400).json({ 
        message: 'Email and password are required' 
      });
    }
    
    // Find user and include password field
    const user = await User.findOne({ email }).select('+password');
    
    if (!user) {
      return res.status(401).json({ message: 'Invalid email or password' });
    }
    
    // Check password
    const isPasswordValid = await user.comparePassword(password);
    
    if (!isPasswordValid) {
      return res.status(401).json({ message: 'Invalid email or password' });
    }
    
    const token = generateToken(user._id);
    
    // Set HTTP-only cookie
    res.cookie('jwt', token, getCookieOptions());
    
    res.json({
      message: 'Login successful',
      token,
      user: {
        id: user._id,
        username: user.username,
        displayName: user.displayName,
        email: user.email,
        role: user.role
      }
    });
  } catch (error) {
    res.status(500).json({ 
      message: 'Error logging in', 
      error: error.message 
    });
  }
});

/**
 * @swagger
 * /api/auth/me:
 *   get:
 *     summary: Get current user profile
 *     tags: [Authentication]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: User profile retrieved successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 user:
 *                   $ref: '#/components/schemas/User'
 *       401:
 *         description: Unauthorized
 */
// Get current user profile
router.get('/me', authenticate, async (req, res) => {
  try {
    const user = await User.findById(req.user.userId);
    
    res.json({
      user: {
        id: user._id,
        username: user.username,
        displayName: user.displayName,
        email: user.email,
        role: user.role,
        createdAt: user.createdAt
      }
    });
  } catch (error) {
    res.status(500).json({ 
      message: 'Error fetching user profile', 
      error: error.message 
    });
  }
});

/**
 * @swagger
 * /api/auth/logout:
 *   post:
 *     summary: Logout user
 *     tags: [Authentication]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Logout successful
 *       401:
 *         description: Unauthorized
 */
// Logout user - clear cookie
router.post('/logout', authenticate, async (req, res) => {
  try {
    const cookieOptions = getCookieOptions();
    delete cookieOptions.maxAge; // Remove maxAge for clearing cookie
    
    res.clearCookie('jwt', cookieOptions);
    
    res.json({ message: 'Logout successful' });
  } catch (error) {
    res.status(500).json({ 
      message: 'Error logging out', 
      error: error.message 
    });
  }
});

/**
 * @swagger
 * /api/auth/profile:
 *   put:
 *     summary: Update user profile (display name)
 *     tags: [Authentication]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               displayName:
 *                 type: string
 *                 maxLength: 50
 *                 description: Display name (leave empty to clear)
 *     responses:
 *       200:
 *         description: Profile updated successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                 user:
 *                   $ref: '#/components/schemas/User'
 *       400:
 *         description: Invalid input
 *       401:
 *         description: Unauthorized
 */
// Update user profile (display name) - Apply write rate limiting
router.put('/profile', writeLimiter, authenticate, async (req, res) => {
  try {
    const { displayName } = req.body;
    
    // Validate displayName if provided
    if (displayName !== undefined && displayName !== null) {
      if (typeof displayName !== 'string') {
        return res.status(400).json({ 
          message: 'Display name must be a string' 
        });
      }
      
      const trimmedDisplayName = displayName.trim();
      if (trimmedDisplayName.length > 50) {
        return res.status(400).json({ 
          message: 'Display name must not exceed 50 characters' 
        });
      }
    }
    
    // Update user
    const user = await User.findById(req.user.userId);
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }
    
    user.displayName = displayName || null;
    await user.save();
    
    res.json({
      message: 'Profile updated successfully',
      user: {
        id: user._id,
        username: user.username,
        displayName: user.displayName,
        email: user.email,
        role: user.role
      }
    });
  } catch (error) {
    res.status(500).json({ 
      message: 'Error updating profile', 
      error: error.message 
    });
  }
});

/**
 * @swagger
 * /api/auth/create-admin:
 *   post:
 *     summary: Create admin user (superadmin only)
 *     tags: [Authentication]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - username
 *               - email
 *               - password
 *             properties:
 *               username:
 *                 type: string
 *                 minLength: 3
 *               email:
 *                 type: string
 *                 format: email
 *               password:
 *                 type: string
 *                 minLength: 6
 *     responses:
 *       201:
 *         description: Admin user created successfully
 *       400:
 *         description: Invalid input or user already exists
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Forbidden - superadmin role required
 */
// Create admin user (superadmin only) - Apply write rate limiting
router.post('/create-admin', writeLimiter, authenticate, authorize('superadmin'), async (req, res) => {
  try {
    const { username, email, password } = req.body;
    
    // Validate input
    if (!username || !email || !password) {
      return res.status(400).json({ 
        message: 'Username, email, and password are required' 
      });
    }
    
    // Check if user already exists
    const existingUser = await User.findOne({ 
      $or: [{ email }, { username }] 
    });
    
    if (existingUser) {
      return res.status(400).json({ 
        message: 'User with this email or username already exists' 
      });
    }
    
    // Create new admin user
    const adminUser = new User({
      username,
      email,
      password,
      role: 'admin',
      createdBy: req.user.userId
    });
    
    await adminUser.save();
    
    res.status(201).json({
      message: 'Admin user created successfully',
      user: {
        id: adminUser._id,
        username: adminUser.username,
        displayName: adminUser.displayName,
        email: adminUser.email,
        role: adminUser.role
      }
    });
  } catch (error) {
    if (error.code === 11000) {
      return res.status(400).json({ 
        message: 'User with this email or username already exists' 
      });
    }
    res.status(500).json({ 
      message: 'Error creating admin user', 
      error: error.message 
    });
  }
});

/**
 * @swagger
 * /api/auth/create-user:
 *   post:
 *     summary: Create regular user (admin/superadmin only)
 *     tags: [Authentication]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - username
 *               - email
 *               - password
 *             properties:
 *               username:
 *                 type: string
 *                 minLength: 3
 *               email:
 *                 type: string
 *                 format: email
 *               password:
 *                 type: string
 *                 minLength: 6
 *     responses:
 *       201:
 *         description: User created successfully
 *       400:
 *         description: Invalid input or user already exists
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Forbidden - admin or superadmin role required
 */
// Create regular user (admin or superadmin only) - Apply write rate limiting
router.post('/create-user', writeLimiter, authenticate, authorize('admin', 'superadmin'), async (req, res) => {
  try {
    const { username, email, password } = req.body;
    
    // Validate input
    if (!username || !email || !password) {
      return res.status(400).json({ 
        message: 'Username, email, and password are required' 
      });
    }
    
    // Check if user already exists
    const existingUser = await User.findOne({ 
      $or: [{ email }, { username }] 
    });
    
    if (existingUser) {
      return res.status(400).json({ 
        message: 'User with this email or username already exists' 
      });
    }
    
    // Create new regular user
    const newUser = new User({
      username,
      email,
      password,
      role: 'user',
      createdBy: req.user.userId
    });
    
    await newUser.save();
    
    res.status(201).json({
      message: 'User created successfully',
      user: {
        id: newUser._id,
        username: newUser.username,
        displayName: newUser.displayName,
        email: newUser.email,
        role: newUser.role
      }
    });
  } catch (error) {
    if (error.code === 11000) {
      return res.status(400).json({ 
        message: 'User with this email or username already exists' 
      });
    }
    res.status(500).json({ 
      message: 'Error creating user', 
      error: error.message 
    });
  }
});

// Get all users (superadmin only)
router.get('/users', authenticate, authorize('superadmin'), async (req, res) => {
  try {
    const users = await User.find().select('_id username displayName email role createdAt updatedAt');
    const formatted = users.map((u) => ({
      id: u._id,
      username: u.username,
      displayName: u.displayName,
      email: u.email,
      role: u.role,
      createdAt: u.createdAt,
      updatedAt: u.updatedAt
    }));

    res.json({ users: formatted });
  } catch (error) {
    res.status(500).json({ 
      message: 'Error fetching users', 
      error: error.message 
    });
  }
});

// Update user password (superadmin only)
router.put('/users/:id/password', writeLimiter, authenticate, authorize('superadmin'), async (req, res) => {
  try {
    const { password } = req.body;
    const { id } = req.params;

    if (!password || typeof password !== 'string' || password.length < 6) {
      return res.status(400).json({ message: 'La password deve avere almeno 6 caratteri.' });
    }

    const user = await User.findById(id).select('+password');
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    user.password = password;
    await user.save();

    res.json({ message: 'Password aggiornata con successo' });
  } catch (error) {
    res.status(500).json({ 
      message: 'Errore durante l\'aggiornamento della password', 
      error: error.message 
    });
  }
});

module.exports = router;
