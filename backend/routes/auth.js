const express = require('express');
const jwt = require('jsonwebtoken');
const crypto = require('node:crypto');
const { findInviter, notifyRegistration, getInvitation, dismissPrompt, previewInvitation } = require('../services/invitations');
const mongoose = require('mongoose');
const User = require('../models/User');
const Review = require('../models/Review');
const Suggestion = require('../models/Suggestion');
const Restaurant = require('../models/Restaurant');
const { authenticate, authorize } = require('../middleware/auth');
const { authLimiter, writeLimiter } = require('../middleware/rateLimiter');

const router = express.Router();


// Invite links are reusable and valid while the inviting account exists.
router.post('/invitation', authenticate, writeLimiter, getInvitation);
router.patch('/invitation/dismiss', authenticate, writeLimiter, dismissPrompt);
router.get('/invitation/status', authenticate, async (req, res) => {
  try {
    const user = await User.findById(req.user.userId).select('invitationPromptDismissed');
    if (!user) return res.status(404).json({ message: 'Utente non trovato.' });
    return res.json({ dismissed: user.invitationPromptDismissed });
  } catch {
    return res.status(500).json({ message: 'Impossibile caricare la preferenza.' });
  }
});
router.get('/invitation/:token', previewInvitation);

// Generate JWT token
const generateToken = (userId) => {
  return jwt.sign(
    { userId },
    process.env.JWT_SECRET,
    { expiresIn: process.env.JWT_EXPIRES_IN || '365d' }
  );
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
 *               - name
 *               - invitationToken
 *               - email
 *               - password
 *             properties:
 *               name:
 *                 type: string
 *                 maxLength: 50
 *               invitationToken:
 *                 type: string
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
    const { name, email: rawEmail, password, invitationToken } = req.body || {};
    if (typeof name !== 'string' || !name.trim() || name.trim().length > 50 ||
        typeof rawEmail !== 'string' || rawEmail.length > 254 || !/^\S+@\S+\.\S+$/.test(rawEmail.trim()) ||
        typeof password !== 'string' || password.length < 6 || password.length > 128) {
      return res.status(400).json({ message: 'Inserisci nome (massimo 50 caratteri), email valida e password da 6 a 128 caratteri.' });
    }
    const inviter = await findInviter(invitationToken);
    if (!inviter) {
      return res.status(400).json({ message: 'Questo invito non ? valido o non ? pi? disponibile.' });
    }
    const email = rawEmail.trim().toLowerCase();
    if (await User.findOne({ email })) {
      return res.status(400).json({ message: 'Esiste gi? un account con questa email. Accedi al tuo account.' });
    }
    const usernameBase = name.trim().normalize('NFKD').replace(/[\u0300-\u036f]/g, '')
      .toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '').slice(0, 32) || 'utente';
    const user = new User({
      username: `${usernameBase}_${crypto.randomBytes(3).toString('hex')}`,
      displayName: name.trim(),
      email,
      password,
      role: 'user',
      invitedBy: inviter._id
    });
    // Validate signing configuration before committing an account.
    const token = generateToken(user._id);
    await user.save();
    try {
      await notifyRegistration(user);
    } catch (error) {
      // A push provider failure must not turn a successful registration into an error.
      console.error('[invitation] Registration notification failed:', error.message);
    }


    
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
    const users = await User.find()
      .select('_id username displayName email role invitedBy createdAt updatedAt')
      .populate('invitedBy', '_id username displayName email');
    const formatted = users.map((u) => ({
      id: u._id,
      username: u.username,
      displayName: u.displayName,
      email: u.email,
      role: u.role,
      invitedBy: u.invitedBy ? {
        id: u.invitedBy._id,
        username: u.invitedBy.username,
        displayName: u.invitedBy.displayName,
        email: u.invitedBy.email
      } : null,
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

// Delete user account (superadmin only). Reviews intentionally remain in place.
router.delete('/users/:id', writeLimiter, authenticate, authorize('superadmin'), async (req, res) => {
  try {
    const { id } = req.params;

    if (!mongoose.Types.ObjectId.isValid(id)) {
      return res.status(400).json({ message: 'ID utente non valido' });
    }

    if (req.user.userId.toString() === id) {
      return res.status(400).json({ message: 'Non puoi eliminare il tuo account dalla gestione utenti' });
    }

    const user = await User.findById(id);
    if (!user) {
      return res.status(404).json({ message: 'Utente non trovato' });
    }

    if (user.role === 'superadmin') {
      return res.status(403).json({ message: 'Non è possibile eliminare un account superadmin' });
    }

    await User.findByIdAndDelete(id);

    return res.json({
      message: 'Utente eliminato con successo',
      deletedUserId: id
    });
  } catch (error) {
    return res.status(500).json({
      message: 'Errore durante la cancellazione dell\'utente',
      error: error.message
    });
  }
});

// Search users (authenticated users)
const searchUsersHandler = async (req, res) => {
  try {
    const q = (req.query.q || '').toString().trim();
    if (!q) {
      return res.json({ count: 0, users: [] });
    }

    const regex = new RegExp(q.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'i');

    const users = await User.find({
      $or: [
        { username: regex },
        { displayName: regex },
        { email: regex }
      ]
    })
      .select('_id username displayName role') // <-- rimosso email
      .limit(10)
      .sort({ createdAt: -1 });

    return res.json({ count: users.length, users });
  } catch (error) {
    return res.status(500).json({ message: 'Error searching users', error: error.message });
  }
};

router.get('/users/search', authenticate, searchUsersHandler);

// Latest users for authenticated users
router.get('/users/latest', authenticate, async (req, res) => {
  try {
    const parsedLimit = parseInt(req.query.limit, 10);
    const limit = Number.isFinite(parsedLimit)
      ? Math.min(Math.max(parsedLimit, 1), 20)
      : 5;

    const users = await User.find({})
      .select('_id username displayName role createdAt')
      .sort({ createdAt: -1 })
      .limit(limit);

    return res.json({ count: users.length, users });
  } catch (error) {
    return res.status(500).json({ message: 'Error fetching latest users', error: error.message });
  }
});

// Public profile data for authenticated users
router.get('/users/:id/profile', authenticate, async (req, res) => {
  try {
    const { id } = req.params;

    if (!mongoose.Types.ObjectId.isValid(id)) {
      return res.status(400).json({ message: 'Invalid user ID' });
    }

    const [user, reviewCount, pendingSuggestionCount, approvedSuggestionCount] = await Promise.all([
      User.findById(id).select('_id username displayName role createdAt'),
      Review.countDocuments({ user: id }),
      Suggestion.countDocuments({ suggestedBy: id }),
      Restaurant.countDocuments({ suggestedBy: id })
    ]);

    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    return res.json({
      user: {
        id: user._id,
        username: user.username,
        displayName: user.displayName,
        role: user.role,
        createdAt: user.createdAt
      },
      stats: {
        reviewCount,
        suggestedPlaceCount: pendingSuggestionCount + approvedSuggestionCount
      }
    });
  } catch (error) {
    return res.status(500).json({ message: 'Error fetching user profile', error: error.message });
  }
});

module.exports = router;
