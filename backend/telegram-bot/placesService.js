const mongoose = require('mongoose');
const connectDB = require('../config/database');
const Restaurant = require('../models/Restaurant');
const Review = require('../models/Review');

let dbReady = false;

const ensureDb = async () => {
  if (dbReady && mongoose.connection.readyState === 1) {
    return;
  }

  await connectDB();
  dbReady = true;
};

const escapeRegex = (value) => value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

const buildFilters = ({ city, placeType, searchText }) => {
  const filters = [];

  if (city) {
    const cityRegex = new RegExp(escapeRegex(city), 'i');
    filters.push({
      $or: [
        { address: cityRegex },
        { description: cityRegex }
      ]
    });
  }

  if (placeType) {
    const typeRegex = new RegExp(escapeRegex(placeType), 'i');
    filters.push({
      $or: [
        { name: typeRegex },
        { cuisine: typeRegex },
        { description: typeRegex }
      ]
    });
  }

  if (filters.length > 0) {
    return { $and: filters };
  }

  if (searchText) {
    const generic = new RegExp(escapeRegex(searchText), 'i');
    return {
      $or: [
        { name: generic },
        { cuisine: generic },
        { address: generic },
        { description: generic }
      ]
    };
  }

  return {};
};

const addRanking = async (restaurants) => {
  if (!restaurants.length) {
    return [];
  }

  const restaurantIds = restaurants.map((restaurant) => restaurant._id);

  const ratings = await Review.aggregate([
    { $match: { restaurant: { $in: restaurantIds } } },
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
        reviewCount: { $sum: 1 },
        averageRating: { $avg: '$averageRating' }
      }
    }
  ]);

  const ratingsMap = new Map(ratings.map((entry) => [String(entry._id), entry]));

  return restaurants
    .map((restaurant) => {
      const stats = ratingsMap.get(String(restaurant._id));
      const averageRating = stats?.averageRating ? Number(stats.averageRating) : 0;
      const reviewCount = stats?.reviewCount || 0;
      const score = (averageRating * 1.2) + Math.min(reviewCount, 30) / 10;

      return {
        id: String(restaurant._id),
        name: restaurant.name,
        description: restaurant.description || null,
        address: restaurant.address || null,
        cuisine: restaurant.cuisine || null,
        coverImageUrl: restaurant.coverImageUrl || null,
        googleMapsUrl: restaurant.googleMapsUrl || null,
        instagramUrl: restaurant.instagramUrl || null,
        averageRating,
        reviewCount,
        score,
        createdAt: restaurant.createdAt
      };
    })
    .sort((a, b) => {
      if (b.score !== a.score) {
        return b.score - a.score;
      }
      if (b.reviewCount !== a.reviewCount) {
        return b.reviewCount - a.reviewCount;
      }
      return new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime();
    });
};

const findPlaces = async ({ city, placeType, searchText, limit = 8 }) => {
  await ensureDb();

  const baseFilter = buildFilters({ city, placeType, searchText });

  let restaurants = await Restaurant.find(baseFilter)
    .select('_id name description address cuisine coverImageUrl googleMapsUrl instagramUrl createdAt')
    .sort({ createdAt: -1 })
    .limit(50)
    .lean();

  if (!restaurants.length && (city || placeType)) {
    const fallbackText = [placeType, city, searchText]
      .filter(Boolean)
      .join(' ')
      .trim();

    restaurants = await Restaurant.find(buildFilters({ searchText: fallbackText }))
      .select('_id name description address cuisine coverImageUrl googleMapsUrl instagramUrl createdAt')
      .sort({ createdAt: -1 })
      .limit(50)
      .lean();
  }

  const ranked = await addRanking(restaurants);
  return ranked.slice(0, limit);
};

module.exports = {
  findPlaces
};
