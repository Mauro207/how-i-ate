const mongoose = require('mongoose');

const reviewSchema = new mongoose.Schema({
  restaurant: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Restaurant',
    required: true
  },
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  serviceRating: {
    type: Number,
    required: [true, 'Service rating is required'],
    min: [1, 'Service rating must be at least 1'],
    max: [5, 'Service rating cannot exceed 5']
  },
  priceRating: {
    type: Number,
    required: [true, 'Price rating is required'],
    min: [1, 'Price rating must be at least 1'],
    max: [5, 'Price rating cannot exceed 5']
  },
  menuRating: {
    type: Number,
    required: [true, 'Menu rating is required'],
    min: [1, 'Menu rating must be at least 1'],
    max: [5, 'Menu rating cannot exceed 5']
  },
  comment: {
    type: String,
    required: [true, 'Comment is required'],
    trim: true,
    minlength: [5, 'Comment must be at least 5 characters long'],
    maxlength: [500, 'Comment cannot exceed 500 characters']
  }
}, {
  timestamps: true
});

// Prevent duplicate reviews from the same user on the same restaurant
reviewSchema.index({ restaurant: 1, user: 1 }, { unique: true });

const Review = mongoose.model('Review', reviewSchema);

module.exports = Review;
