const mongoose = require('mongoose');

const suggestionSchema = new mongoose.Schema({
  name: {
    type: String,
    required: [true, 'Restaurant name is required'],
    trim: true,
    minlength: [2, 'Restaurant name must be at least 2 characters long']
  },
  description: {
    type: String,
    trim: true,
    maxlength: [1000, 'Description cannot exceed 1000 characters']
  },
  address: {
    type: String,
    trim: true
  },
  cuisine: {
    type: String,
    trim: true
  },
  instagramUrl: {
    type: String,
    trim: true,
    maxlength: [2048, 'Instagram URL is too long'],
    validate: {
      validator: function (value) {
        if (!value) return true;

        try {
          const parsed = new URL(value);
          const protocol = parsed.protocol.toLowerCase();
          const host = parsed.hostname.toLowerCase();
          const isInstagramDomain =
            host === 'instagram.com' ||
            host === 'www.instagram.com' ||
            host === 'instagr.am' ||
            host.endsWith('.instagram.com');

          return (protocol === 'http:' || protocol === 'https:') && isInstagramDomain;
        } catch {
          return false;
        }
      },
      message: 'Instagram URL is not valid'
    }
  },
  status: {
    type: String,
    enum: ['pending'],
    default: 'pending'
  },
  suggestedBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  }
}, {
  timestamps: true
});

const Suggestion = mongoose.model('Suggestion', suggestionSchema);

module.exports = Suggestion;
