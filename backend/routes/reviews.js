const express = require('express');
const mongoose = require('mongoose');
const Review = require('../models/Review');
const Restaurant = require('../models/Restaurant');
const User = require('../models/User');
const { authenticate, authorize } = require('../middleware/auth');
const { writeLimiter } = require('../middleware/rateLimiter');

const router = express.Router();

/**
 * @swagger
 * /api/reviews/rankings/global:
 *   get:
 *     summary: Get global restaurant rankings based on average ratings
 *     tags: [Reviews]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: List of restaurants with their average ratings
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 rankings:
 *                   type: array
 *                   items:
 *                     type: object
 */
// Get global restaurant rankings
router.get('/rankings/global', authenticate, async (req, res) => {
  try {
    const rankings = await Review.aggregate([
      {
        $addFields: {
          averageRating: {
            $avg: ['$serviceRating', '$priceRating', '$menuRating']
          }
        }
      },
      {
        $group: {
          _id: '$restaurant',
          averageRating: { $avg: '$averageRating' },
          reviewCount: { $sum: 1 }
        }
      },
      {
        $lookup: {
          from: 'restaurants',
          localField: '_id',
          foreignField: '_id',
          as: 'restaurant'
        }
      },
      {
        $unwind: '$restaurant'
      },
      {
        $sort: { averageRating: -1 }
      },
      {
        $project: {
          restaurantId: '$_id',
          restaurantName: '$restaurant.name',
          cuisine: '$restaurant.cuisine',
          address: '$restaurant.address',
          averageRating: { $round: ['$averageRating', 2] },
          reviewCount: 1
        }
      }
    ]);

    res.json({ rankings });
  } catch (error) {
    res.status(500).json({ 
      message: 'Error fetching global rankings', 
      error: error.message 
    });
  }
});

/**
 * @swagger
 * /api/reviews/rankings/user/{userId}:
 *   get:
 *     summary: Get restaurant rankings for a specific user
 *     tags: [Reviews]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: userId
 *         required: true
 *         schema:
 *           type: string
 *         description: User ID
 *     responses:
 *       200:
 *         description: List of restaurants reviewed by the user with their ratings
 */
// Get user-specific restaurant rankings
router.get('/rankings/user/:userId', authenticate, async (req, res) => {
  try {
    // Validate userId is a valid ObjectId
    if (!mongoose.Types.ObjectId.isValid(req.params.userId)) {
      return res.status(400).json({ message: 'Invalid user ID' });
    }

    const rankings = await Review.aggregate([
      {
        $match: { user: new mongoose.Types.ObjectId(req.params.userId) }
      },
      {
        $addFields: {
          averageRating: {
            $avg: ['$serviceRating', '$priceRating', '$menuRating']
          }
        }
      },
      {
        $lookup: {
          from: 'restaurants',
          localField: 'restaurant',
          foreignField: '_id',
          as: 'restaurant'
        }
      },
      {
        $unwind: '$restaurant'
      },
      {
        $sort: { averageRating: -1 }
      },
      {
        $project: {
          restaurantId: '$restaurant._id',
          restaurantName: '$restaurant.name',
          cuisine: '$restaurant.cuisine',
          address: '$restaurant.address',
          averageRating: { $round: ['$averageRating', 2] },
          serviceRating: 1,
          priceRating: 1,
          menuRating: 1,
          comment: 1,
          createdAt: 1
        }
      }
    ]);

    res.json({ rankings });
  } catch (error) {
    res.status(500).json({ 
      message: 'Error fetching user rankings', 
      error: error.message 
    });
  }
});

/**
 * @swagger
 * /api/reviews/restaurant/{restaurantId}:
 *   get:
 *     summary: Get all reviews for a restaurant
 *     tags: [Reviews]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: restaurantId
 *         required: true
 *         schema:
 *           type: string
 *         description: Restaurant ID
 *     responses:
 *       200:
 *         description: List of reviews
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 count:
 *                   type: integer
 *                 reviews:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/Review'
 *       404:
 *         description: Restaurant not found
 */
// Get all reviews for a restaurant
router.get('/restaurant/:restaurantId', authenticate, async (req, res) => {
  try {
    const restaurant = await Restaurant.findById(req.params.restaurantId);
    
    if (!restaurant) {
      return res.status(404).json({ message: 'Restaurant not found' });
    }
    
    const reviews = await Review.find({ restaurant: req.params.restaurantId })
      .populate('user', 'username email displayName')
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

/**
 * @swagger
 * /api/reviews/{id}:
 *   get:
 *     summary: Get single review
 *     tags: [Reviews]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: Review ID
 *     responses:
 *       200:
 *         description: Review details
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 review:
 *                   $ref: '#/components/schemas/Review'
 *       404:
 *         description: Review not found
 */
// Get single review
router.get('/:id', authenticate, async (req, res) => {
  try {
    const review = await Review.findById(req.params.id)
      .populate('user', 'username email displayName')
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

/**
 * @swagger
 * /api/reviews/restaurant/{restaurantId}:
 *   post:
 *     summary: Create review (authenticated users)
 *     tags: [Reviews]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: restaurantId
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
 *             required:
 *               - serviceRating
 *               - priceRating
 *               - menuRating
 *               - comment
 *             properties:
 *               serviceRating:
 *                 type: integer
 *                 minimum: 1
 *                 maximum: 5
 *               priceRating:
 *                 type: integer
 *                 minimum: 1
 *                 maximum: 5
 *               menuRating:
 *                 type: integer
 *                 minimum: 1
 *                 maximum: 5
 *               comment:
 *                 type: string
 *     responses:
 *       201:
 *         description: Review created successfully
 *       400:
 *         description: Invalid input or already reviewed
 *       404:
 *         description: Restaurant not found
 */
// Create review (all authenticated users) - Apply write rate limiting
router.post('/restaurant/:restaurantId', writeLimiter, authenticate, async (req, res) => {
  try {
    const { serviceRating, priceRating, menuRating, comment } = req.body;
    
    // Validate input
    if (!serviceRating || !priceRating || !menuRating || !comment) {
      return res.status(400).json({ 
        message: 'Service rating, price rating, menu rating, and comment are required' 
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
      serviceRating,
      priceRating,
      menuRating,
      comment
    });
    
    await review.save();
    
    await review.populate('user', 'username email displayName');
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

/**
 * @swagger
 * /api/reviews/batch:
 *   post:
 *     summary: Create multiple reviews (superadmin only, can act on behalf of other users)
 *     tags: [Reviews]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - reviews
 *             properties:
 *               reviews:
 *                 type: array
 *                 items:
 *                   type: object
 *                   required:
 *                     - restaurantId
 *                     - userId
 *                     - serviceRating
 *                     - priceRating
 *                     - menuRating
 *                     - comment
 *                   properties:
 *                     restaurantId:
 *                       type: string
 *                     userId:
 *                       type: string
 *                     serviceRating:
 *                       type: integer
 *                       minimum: 1
 *                       maximum: 5
 *                     priceRating:
 *                       type: integer
 *                       minimum: 1
 *                       maximum: 5
 *                     menuRating:
 *                       type: integer
 *                       minimum: 1
 *                       maximum: 5
 *                     comment:
 *                       type: string
 *     responses:
 *       201:
 *         description: Reviews created successfully
 *       400:
 *         description: Invalid input
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Forbidden - superadmin role required
 */
// Create multiple reviews (superadmin only, can impersonate users) - Apply write rate limiting
router.post('/batch', writeLimiter, authenticate, authorize('superadmin'), async (req, res) => {
  try {
    const { reviews } = req.body;
    
    // Validate input
    if (!reviews || !Array.isArray(reviews) || reviews.length === 0) {
      return res.status(400).json({ message: 'Reviews array is required and must not be empty' });
    }
    
    // Validate each review
    for (const rev of reviews) {
      if (!rev.restaurantId || !rev.userId || !rev.serviceRating || !rev.priceRating || !rev.menuRating || !rev.comment) {
        return res.status(400).json({ 
          message: 'Each review must have restaurantId, userId, serviceRating, priceRating, menuRating, and comment' 
        });
      }
    }
    
    // Create all reviews
    const createdReviews = [];
    const errors = [];
    
    for (const revData of reviews) {
      try {
        // Check if restaurant exists
        const restaurant = await Restaurant.findById(revData.restaurantId);
        
        if (!restaurant) {
          errors.push({
            restaurantId: revData.restaurantId,
            userId: revData.userId,
            error: 'Restaurant not found'
          });
          continue;
        }

        // Check if target user exists
        const targetUser = await User.findById(revData.userId);

        if (!targetUser) {
          errors.push({
            restaurantId: revData.restaurantId,
            userId: revData.userId,
            error: 'User not found'
          });
          continue;
        }
        
        // Check if user has already reviewed this restaurant
        const existingReview = await Review.findOne({
          restaurant: revData.restaurantId,
          user: revData.userId
        });
        
        if (existingReview) {
          errors.push({
            restaurantId: revData.restaurantId,
            userId: revData.userId,
            error: 'User has already reviewed this restaurant'
          });
          continue;
        }
        
        const review = new Review({
          restaurant: revData.restaurantId,
          user: revData.userId,
          serviceRating: revData.serviceRating,
          priceRating: revData.priceRating,
          menuRating: revData.menuRating,
          comment: revData.comment
        });
        
        await review.save();
        await review.populate('user', 'username email displayName');
        await review.populate('restaurant', 'name');
        
        createdReviews.push(review);
      } catch (error) {
        errors.push({
          restaurantId: revData.restaurantId,
          userId: revData.userId,
          error: error.message
        });
      }
    }
    
    res.status(201).json({
      message: `${createdReviews.length} reviews created successfully`,
      created: createdReviews.length,
      failed: errors.length,
      reviews: createdReviews,
      errors: errors.length > 0 ? errors : undefined
    });
  } catch (error) {
    res.status(500).json({ 
      message: 'Error creating reviews', 
      error: error.message 
    });
  }
});

/**
 * @swagger
 * /api/reviews/{id}:
 *   put:
 *     summary: Update review (owner only)
 *     tags: [Reviews]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: Review ID
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               serviceRating:
 *                 type: integer
 *                 minimum: 1
 *                 maximum: 5
 *               priceRating:
 *                 type: integer
 *                 minimum: 1
 *                 maximum: 5
 *               menuRating:
 *                 type: integer
 *                 minimum: 1
 *                 maximum: 5
 *               comment:
 *                 type: string
 *     responses:
 *       200:
 *         description: Review updated successfully
 *       404:
 *         description: Review not found
 *       403:
 *         description: Forbidden - not review owner
 */
// Update review (review owner, admin, or superadmin) - Apply write rate limiting
router.put('/:id', writeLimiter, authenticate, async (req, res) => {
  try {
    const { serviceRating, priceRating, menuRating, comment } = req.body;
    
    const review = await Review.findById(req.params.id);
    
    if (!review) {
      return res.status(404).json({ message: 'Review not found' });
    }
    
    // Check if user is the owner of the review or has admin/superadmin role
    const isOwner = review.user.toString() === req.user.userId.toString();
    const isAdminOrSuperadmin = ['admin', 'superadmin'].includes(req.user.role);
    
    if (!isOwner && !isAdminOrSuperadmin) {
      return res.status(403).json({ 
        message: 'You can only update your own reviews' 
      });
    }
    
    // Update fields if provided
    if (serviceRating !== undefined) review.serviceRating = serviceRating;
    if (priceRating !== undefined) review.priceRating = priceRating;
    if (menuRating !== undefined) review.menuRating = menuRating;
    if (comment !== undefined) review.comment = comment;
    
    await review.save();
    
    await review.populate('user', 'username email displayName');
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

/**
 * @swagger
 * /api/reviews/{id}:
 *   delete:
 *     summary: Delete review (owner/admin/superadmin)
 *     tags: [Reviews]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: Review ID
 *     responses:
 *       200:
 *         description: Review deleted successfully
 *       404:
 *         description: Review not found
 *       403:
 *         description: Forbidden - not authorized to delete
 */
// Delete review (review owner, admin, or superadmin) - Apply write rate limiting
router.delete('/:id', writeLimiter, authenticate, async (req, res) => {
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
