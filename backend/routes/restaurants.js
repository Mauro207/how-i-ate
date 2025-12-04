const express = require('express');
const Restaurant = require('../models/Restaurant');
const { authenticate, authorize } = require('../middleware/auth');

const router = express.Router();

// Get all restaurants (all authenticated users)
router.get('/', authenticate, async (req, res) => {
  try {
    const restaurants = await Restaurant.find()
      .populate('createdBy', 'username email')
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

// Get single restaurant (all authenticated users)
router.get('/:id', authenticate, async (req, res) => {
  try {
    const restaurant = await Restaurant.findById(req.params.id)
      .populate('createdBy', 'username email');
    
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

// Create restaurant (admin and superadmin only)
router.post('/', authenticate, authorize('admin', 'superadmin'), async (req, res) => {
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
    
    await restaurant.populate('createdBy', 'username email');
    
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

// Update restaurant (admin and superadmin only)
router.put('/:id', authenticate, authorize('admin', 'superadmin'), async (req, res) => {
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
    
    await restaurant.populate('createdBy', 'username email');
    
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

// Delete restaurant (admin and superadmin only)
router.delete('/:id', authenticate, authorize('admin', 'superadmin'), async (req, res) => {
  try {
    const restaurant = await Restaurant.findById(req.params.id);
    
    if (!restaurant) {
      return res.status(404).json({ message: 'Restaurant not found' });
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
