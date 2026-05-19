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

const normalizeText = (value) => (value || '')
  .toString()
  .toLowerCase()
  .normalize('NFD')
  .replace(/[\u0300-\u036f]/g, '')
  .trim();

const buildBigrams = (value) => {
  const cleaned = normalizeText(value).replace(/\s+/g, ' ');
  if (cleaned.length < 2) {
    return new Set(cleaned ? [cleaned] : []);
  }

  const bigrams = new Set();
  for (let i = 0; i < cleaned.length - 1; i += 1) {
    bigrams.add(cleaned.slice(i, i + 2));
  }
  return bigrams;
};

const diceSimilarity = (a, b) => {
  const aBigrams = buildBigrams(a);
  const bBigrams = buildBigrams(b);

  if (!aBigrams.size || !bBigrams.size) {
    return 0;
  }

  let intersection = 0;
  for (const token of aBigrams) {
    if (bBigrams.has(token)) {
      intersection += 1;
    }
  }

  return (2 * intersection) / (aBigrams.size + bBigrams.size);
};

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
        createdAt: restaurant.createdAt
      };
    })
    .sort((a, b) => {
      if (b.averageRating !== a.averageRating) {
        return b.averageRating - a.averageRating;
      }
      if (b.reviewCount !== a.reviewCount) {
        return b.reviewCount - a.reviewCount;
      }
      return new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime();
    });
};

const rankByNearbyMatch = ({ city, places }) => {
  if (!city) {
    return places;
  }

  return places
    .map((place) => {
      const proximity = Math.max(
        diceSimilarity(city, place.address),
        diceSimilarity(city, place.description),
        diceSimilarity(city, place.name)
      );

      return {
        ...place,
        proximity
      };
    })
    .sort((a, b) => {
      if (b.proximity !== a.proximity) {
        return b.proximity - a.proximity;
      }
      if (b.averageRating !== a.averageRating) {
        return b.averageRating - a.averageRating;
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
  const reviewedInRequestedArea = ranked.filter((place) => place.reviewCount > 0);

  if (reviewedInRequestedArea.length) {
    return {
      places: reviewedInRequestedArea.slice(0, limit),
      usedNearbyFallback: false
    };
  }

  if (city) {
    const nearbyFilter = buildFilters({
      city: null,
      placeType,
      searchText: placeType || searchText
    });

    const nearbyRestaurants = await Restaurant.find(nearbyFilter)
      .select('_id name description address cuisine coverImageUrl googleMapsUrl instagramUrl createdAt')
      .sort({ createdAt: -1 })
      .limit(200)
      .lean();

    const nearbyRanked = await addRanking(nearbyRestaurants);
    const nearbyReviewed = nearbyRanked.filter((place) => place.reviewCount > 0);
    const nearestReviewed = rankByNearbyMatch({ city, places: nearbyReviewed });

    if (nearestReviewed.length) {
      return {
        places: nearestReviewed.slice(0, limit),
        usedNearbyFallback: true
      };
    }
  }

  return {
    places: [],
    usedNearbyFallback: false
  };
};

module.exports = {
  findPlaces
};
