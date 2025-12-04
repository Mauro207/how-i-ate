const express = require('express');
const Restaurant = require('../models/Restaurant');
const { authenticate, authorize } = require('../middleware/auth');
const { writeLimiter } = require('../middleware/rateLimiter');

const router = express.Router();

/**
 * @swagger
 * /api/restaurants:
 *   get:
 *     summary: Get all restaurants
 *     tags: [Restaurants]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: List of restaurants
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 count:
 *                   type: integer
 *                 restaurants:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/Restaurant'
 */
// Get all restaurants (all authenticated users)
router.get('/', authenticate, async (req, res) => {
  try {
    const restaurants = await Restaurant.find()
      .populate('createdBy', 'username email displayName')
      .sort({ createdAt: -1 });
    
    res.json({
      count: restaurants.length,
      restaurants
    });
  } catch (error) {
    res.status(500).json({ 
      message: 'Error fetching restaurants', 
      error: error.message 
    });
  }
});

/**
 * @swagger
 * /api/restaurants/{id}:
 *   get:
 *     summary: Get single restaurant
 *     tags: [Restaurants]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: Restaurant ID
 *     responses:
 *       200:
 *         description: Restaurant details
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 restaurant:
 *                   $ref: '#/components/schemas/Restaurant'
 *       404:
 *         description: Restaurant not found
 */
// Get single restaurant (all authenticated users)
router.get('/:id', authenticate, async (req, res) => {
  try {
    const restaurant = await Restaurant.findById(req.params.id)
      .populate('createdBy', 'username email displayName');
    
    if (!restaurant) {
      return res.status(404).json({ message: 'Restaurant not found' });
    }
    
    res.json({ restaurant });
  } catch (error) {
    if (error.kind === 'ObjectId') {
      return res.status(404).json({ message: 'Restaurant not found' });
    }
    res.status(500).json({ 
      message: 'Error fetching restaurant', 
      error: error.message 
    });
  }
});

/**
 * @swagger
 * /api/restaurants:
 *   post:
 *     summary: Create restaurant (admin/superadmin only)
 *     tags: [Restaurants]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - name
 *             properties:
 *               name:
 *                 type: string
 *               description:
 *                 type: string
 *               address:
 *                 type: string
 *               cuisine:
 *                 type: string
 *     responses:
 *       201:
 *         description: Restaurant created successfully
 *       400:
 *         description: Invalid input
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Forbidden - admin role required
 */
// Create restaurant (admin and superadmin only) - Apply write rate limiting
router.post('/', writeLimiter, authenticate, authorize('admin', 'superadmin'), async (req, res) => {
  try {
    const { name, description, address, cuisine } = req.body;
    
    // Validate input
    if (!name) {
      return res.status(400).json({ message: 'Restaurant name is required' });
    }
    
    const restaurant = new Restaurant({
      name,
      description,
      address,
      cuisine,
      createdBy: req.user.userId
    });
    
    await restaurant.save();
    
    await restaurant.populate('createdBy', 'username email displayName');
    
    res.status(201).json({
      message: 'Restaurant created successfully',
      restaurant
    });
  } catch (error) {
    res.status(500).json({ 
      message: 'Error creating restaurant', 
      error: error.message 
    });
  }
});

/**
 * @swagger
 * /api/restaurants/{id}:
 *   put:
 *     summary: Update restaurant (admin/superadmin only)
 *     tags: [Restaurants]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: Restaurant ID
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               name:
 *                 type: string
 *               description:
 *                 type: string
 *               address:
 *                 type: string
 *               cuisine:
 *                 type: string
 *     responses:
 *       200:
 *         description: Restaurant updated successfully
 *       404:
 *         description: Restaurant not found
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Forbidden - admin role required
 */
// Update restaurant (admin and superadmin only) - Apply write rate limiting
router.put('/:id', writeLimiter, authenticate, authorize('admin', 'superadmin'), async (req, res) => {
  try {
    const { name, description, address, cuisine } = req.body;
    
    const restaurant = await Restaurant.findById(req.params.id);
    
    if (!restaurant) {
      return res.status(404).json({ message: 'Restaurant not found' });
    }
    
    // Update fields if provided
    if (name !== undefined) restaurant.name = name;
    if (description !== undefined) restaurant.description = description;
    if (address !== undefined) restaurant.address = address;
    if (cuisine !== undefined) restaurant.cuisine = cuisine;
    
    await restaurant.save();
    
    await restaurant.populate('createdBy', 'username email displayName');
    
    res.json({
      message: 'Restaurant updated successfully',
      restaurant
    });
  } catch (error) {
    if (error.kind === 'ObjectId') {
      return res.status(404).json({ message: 'Restaurant not found' });
    }
    res.status(500).json({ 
      message: 'Error updating restaurant', 
      error: error.message 
    });
  }
});

/**
 * @swagger
 * /api/restaurants/{id}:
 *   delete:
 *     summary: Delete restaurant (admin/superadmin only)
 *     tags: [Restaurants]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: Restaurant ID
 *     responses:
 *       200:
 *         description: Restaurant deleted successfully
 *       404:
 *         description: Restaurant not found
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Forbidden - admin role required
 */
// Delete restaurant (creator, or any admin/superadmin) - Apply write rate limiting
router.delete('/:id', writeLimiter, authenticate, authorize('admin', 'superadmin'), async (req, res) => {
  try {
    const restaurant = await Restaurant.findById(req.params.id);
    
    if (!restaurant) {
      return res.status(404).json({ message: 'Restaurant not found' });
    }
    
    // Check if user is the creator or has admin/superadmin role
    const isCreator = restaurant.createdBy.toString() === req.user.userId.toString();
    const isAdminOrSuperadmin = ['admin', 'superadmin'].includes(req.user.role);
    
    if (!isCreator && !isAdminOrSuperadmin) {
      return res.status(403).json({ 
        message: 'You can only delete restaurants you created' 
      });
    }
    
    await Restaurant.findByIdAndDelete(req.params.id);
    
    res.json({ message: 'Restaurant deleted successfully' });
  } catch (error) {
    if (error.kind === 'ObjectId') {
      return res.status(404).json({ message: 'Restaurant not found' });
    }
    res.status(500).json({ 
      message: 'Error deleting restaurant', 
      error: error.message 
    });
  }
});

module.exports = router;
