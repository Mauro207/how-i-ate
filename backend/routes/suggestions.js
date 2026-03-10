const express = require('express');
const Suggestion = require('../models/Suggestion');
const Restaurant = require('../models/Restaurant');
const { authenticate, authorize } = require('../middleware/auth');
const { writeLimiter } = require('../middleware/rateLimiter');

const router = express.Router();

// Submit a suggestion (all authenticated users)
router.post('/', writeLimiter, authenticate, async (req, res) => {
  try {
    const { name, description, address, cuisine } = req.body;

    if (!name) {
      return res.status(400).json({ message: 'Restaurant name is required' });
    }

    const suggestion = new Suggestion({
      name,
      description,
      address,
      cuisine,
      suggestedBy: req.user.userId
    });

    await suggestion.save();
    await suggestion.populate('suggestedBy', 'username email displayName');

    res.status(201).json({
      message: 'Suggestion submitted successfully',
      suggestion
    });
  } catch (error) {
    res.status(500).json({
      message: 'Error submitting suggestion',
      error: error.message
    });
  }
});

// Get all pending suggestions (admin/superadmin only)
router.get('/', authenticate, authorize('admin', 'superadmin'), async (req, res) => {
  try {
    const suggestions = await Suggestion.find({ status: 'pending' })
      .populate('suggestedBy', 'username email displayName')
      .sort({ createdAt: -1 });

    res.json({
      count: suggestions.length,
      suggestions
    });
  } catch (error) {
    res.status(500).json({
      message: 'Error fetching suggestions',
      error: error.message
    });
  }
});

// Approve a suggestion (admin/superadmin only) - creates a restaurant from it
router.put('/:id/approve', writeLimiter, authenticate, authorize('admin', 'superadmin'), async (req, res) => {
  try {
    const suggestion = await Suggestion.findById(req.params.id);

    if (!suggestion) {
      return res.status(404).json({ message: 'Suggestion not found' });
    }

    const restaurant = new Restaurant({
      name: suggestion.name,
      description: suggestion.description,
      address: suggestion.address,
      cuisine: suggestion.cuisine,
      createdBy: req.user.userId
    });

    await restaurant.save();
    await restaurant.populate('createdBy', 'username email displayName');

    await Suggestion.findByIdAndDelete(req.params.id);

    res.json({
      message: 'Suggestion approved and restaurant created',
      restaurant
    });
  } catch (error) {
    if (error.kind === 'ObjectId') {
      return res.status(404).json({ message: 'Suggestion not found' });
    }
    res.status(500).json({
      message: 'Error approving suggestion',
      error: error.message
    });
  }
});

// Reject a suggestion (admin/superadmin only) - deletes it
router.delete('/:id', writeLimiter, authenticate, authorize('admin', 'superadmin'), async (req, res) => {
  try {
    const deleted = await Suggestion.findByIdAndDelete(req.params.id);

    if (!deleted) {
      return res.status(404).json({ message: 'Suggestion not found' });
    }

    res.json({ message: 'Suggestion rejected' });
  } catch (error) {
    if (error.kind === 'ObjectId') {
      return res.status(404).json({ message: 'Suggestion not found' });
    }
    res.status(500).json({
      message: 'Error rejecting suggestion',
      error: error.message
    });
  }
});

module.exports = router;
