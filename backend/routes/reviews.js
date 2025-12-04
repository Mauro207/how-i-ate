const express = require('express');
const Review = require('../models/Review');
const Restaurant = require('../models/Restaurant');
const { authenticate, authorize } = require('../middleware/auth');

const router = express.Router();

// Get all reviews for a restaurant
router.get('/restaurant/:restaurantId', authenticate, async (req, res) => {
  try {
    const restaurant = await Restaurant.findById(req.params.restaurantId);
    
    if (!restaurant) {
      return res.status(404).json({ message: 'Restaurant not found' });
    }
    
    const reviews = await Review.find({ restaurant: req.params.restaurantId })
      .populate('user', 'username email')
      .sort({ createdAt: -1 });
    
    res.json({
      count: reviews.length,
      reviews
    });
  } catch (error) {
    if (error.kind === 'ObjectId') {
      return res.status(404).json({ message: 'Restaurant not found' });
    }
    res.status(500).json({ 
      message: 'Error fetching reviews', 
      error: error.message 
    });
  }
});

// Get single review
router.get('/:id', authenticate, async (req, res) => {
  try {
    const review = await Review.findById(req.params.id)
      .populate('user', 'username email')
      .populate('restaurant', 'name');
    
    if (!review) {
      return res.status(404).json({ message: 'Review not found' });
    }
    
    res.json({ review });
  } catch (error) {
    if (error.kind === 'ObjectId') {
      return res.status(404).json({ message: 'Review not found' });
    }
    res.status(500).json({ 
      message: 'Error fetching review', 
      error: error.message 
    });
  }
});

// Create review (all authenticated users)
router.post('/restaurant/:restaurantId', authenticate, async (req, res) => {
  try {
    const { rating, comment } = req.body;
    
    // Validate input
    if (!rating || !comment) {
      return res.status(400).json({ 
        message: 'Rating and comment are required' 
      });
    }
    
    // Check if restaurant exists
    const restaurant = await Restaurant.findById(req.params.restaurantId);
    
    if (!restaurant) {
      return res.status(404).json({ message: 'Restaurant not found' });
    }
    
    // Check if user has already reviewed this restaurant
    const existingReview = await Review.findOne({
      restaurant: req.params.restaurantId,
      user: req.user.userId
    });
    
    if (existingReview) {
      return res.status(400).json({ 
        message: 'You have already reviewed this restaurant' 
      });
    }
    
    const review = new Review({
      restaurant: req.params.restaurantId,
      user: req.user.userId,
      rating,
      comment
    });
    
    await review.save();
    
    await review.populate('user', 'username email');
    await review.populate('restaurant', 'name');
    
    res.status(201).json({
      message: 'Review created successfully',
      review
    });
  } catch (error) {
    if (error.kind === 'ObjectId') {
      return res.status(404).json({ message: 'Restaurant not found' });
    }
    if (error.code === 11000) {
      return res.status(400).json({ 
        message: 'You have already reviewed this restaurant' 
      });
    }
    res.status(500).json({ 
      message: 'Error creating review', 
      error: error.message 
    });
  }
});

// Update review (review owner only)
router.put('/:id', authenticate, async (req, res) => {
  try {
    const { rating, comment } = req.body;
    
    const review = await Review.findById(req.params.id);
    
    if (!review) {
      return res.status(404).json({ message: 'Review not found' });
    }
    
    // Check if user is the owner of the review
    if (review.user.toString() !== req.user.userId.toString()) {
      return res.status(403).json({ 
        message: 'You can only update your own reviews' 
      });
    }
    
    // Update fields if provided
    if (rating !== undefined) review.rating = rating;
    if (comment !== undefined) review.comment = comment;
    
    await review.save();
    
    await review.populate('user', 'username email');
    await review.populate('restaurant', 'name');
    
    res.json({
      message: 'Review updated successfully',
      review
    });
  } catch (error) {
    if (error.kind === 'ObjectId') {
      return res.status(404).json({ message: 'Review not found' });
    }
    res.status(500).json({ 
      message: 'Error updating review', 
      error: error.message 
    });
  }
});

// Delete review (review owner, admin, or superadmin)
router.delete('/:id', authenticate, async (req, res) => {
  try {
    const review = await Review.findById(req.params.id);
    
    if (!review) {
      return res.status(404).json({ message: 'Review not found' });
    }
    
    // Check if user is the owner or has admin/superadmin role
    const isOwner = review.user.toString() === req.user.userId.toString();
    const isAdminOrSuperadmin = ['admin', 'superadmin'].includes(req.user.role);
    
    if (!isOwner && !isAdminOrSuperadmin) {
      return res.status(403).json({ 
        message: 'You can only delete your own reviews' 
      });
    }
    
    await Review.findByIdAndDelete(req.params.id);
    
    res.json({ message: 'Review deleted successfully' });
  } catch (error) {
    if (error.kind === 'ObjectId') {
      return res.status(404).json({ message: 'Review not found' });
    }
    res.status(500).json({ 
      message: 'Error deleting review', 
      error: error.message 
    });
  }
});

module.exports = router;
