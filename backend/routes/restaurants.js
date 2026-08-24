const express = require('express');
const Restaurant = require('../models/Restaurant');
const Review = require('../models/Review');
const { authenticate, authorize } = require('../middleware/auth');
const { writeLimiter } = require('../middleware/rateLimiter');
const { sendPushToAll } = require('../services/pushNotifications');
const { generateContent: generateGeminiContent } = require('../services/gemini');

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
 * /api/restaurants/search:
 *   get:
 *     summary: Search restaurants by name, cuisine, or address
 *     tags: [Restaurants]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: q
 *         schema:
 *           type: string
 *         description: Search query (searches name, cuisine, address)
 *       - in: query
 *         name: cuisine
 *         schema:
 *           type: string
 *         description: Filter by cuisine type
 *     responses:
 *       200:
 *         description: List of matching restaurants
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
// Search restaurants
router.get('/search', authenticate, async (req, res) => {
  try {
    const { q, cuisine } = req.query;
    let query = {};

    const escapeRegex = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

    if (q) {
      const safeQ = escapeRegex(q.toString().trim());
      query.$or = [
        { name: { $regex: safeQ, $options: 'i' } },
        { cuisine: { $regex: safeQ, $options: 'i' } },
        { address: { $regex: safeQ, $options: 'i' } },
        { description: { $regex: safeQ, $options: 'i' } }
      ];
    }

    if (cuisine) {
      const safeCuisine = escapeRegex(cuisine.toString().trim());
      query.cuisine = { $regex: safeCuisine, $options: 'i' };
    }

    const restaurants = await Restaurant.find(query)
      .select('_id name cuisine address') // autocomplete payload leggero
      .limit(10)
      .sort({ createdAt: -1 });

    res.json({
      count: restaurants.length,
      restaurants
    });
  } catch (error) {
    res.status(500).json({
      message: 'Error searching restaurants',
      error: error.message
    });
  }
});

// Google Places autocomplete (admin/superadmin only)
router.get('/places/autocomplete', authenticate, authorize('admin', 'superadmin'), async (req, res) => {
  try {
    const placesApiKey = process.env.GOOGLE_PLACES_API;
    if (!placesApiKey) {
      return res.status(500).json({ message: 'GOOGLE_PLACES_API non configurata sul backend' });
    }

    const query = (req.query.q || '').toString().trim();
    if (query.length < 2) {
      return res.json({ count: 0, suggestions: [] });
    }

    const params = new URLSearchParams({
      input: query,
      types: 'establishment',
      components: 'country:it',
      language: 'it',
      key: placesApiKey
    });

    const response = await fetch(`https://maps.googleapis.com/maps/api/place/autocomplete/json?${params.toString()}`);
    if (!response.ok) {
      const errorText = await response.text();
      return res.status(502).json({
        message: 'Servizio Google Places non disponibile',
        error: process.env.NODE_ENV === 'development' ? errorText : undefined
      });
    }

    const data = await response.json();
    if (data.status !== 'OK' && data.status !== 'ZERO_RESULTS') {
      return res.status(502).json({
        message: 'Errore da Google Places autocomplete',
        error: process.env.NODE_ENV === 'development' ? data.error_message || data.status : undefined
      });
    }

    const suggestions = (data.predictions || []).slice(0, 5).map((prediction) => ({
      placeId: prediction.place_id,
      description: prediction.description,
      mainText: prediction.structured_formatting?.main_text || prediction.description,
      secondaryText: prediction.structured_formatting?.secondary_text || ''
    }));

    return res.json({
      count: suggestions.length,
      suggestions
    });
  } catch (error) {
    return res.status(500).json({
      message: 'Errore nel recupero suggerimenti Google Places',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
});

// Google Places details (admin/superadmin only)
router.get('/places/details', authenticate, authorize('admin', 'superadmin'), async (req, res) => {
  try {
    const placesApiKey = process.env.GOOGLE_PLACES_API;
    if (!placesApiKey) {
      return res.status(500).json({ message: 'GOOGLE_PLACES_API non configurata sul backend' });
    }

    const placeId = (req.query.placeId || '').toString().trim();
    if (!placeId) {
      return res.status(400).json({ message: 'placeId è obbligatorio' });
    }

    const params = new URLSearchParams({
      place_id: placeId,
      fields: 'name,url,address_component',
      language: 'it',
      key: placesApiKey
    });

    const response = await fetch(`https://maps.googleapis.com/maps/api/place/details/json?${params.toString()}`);
    if (!response.ok) {
      const errorText = await response.text();
      return res.status(502).json({
        message: 'Servizio Google Places non disponibile',
        error: process.env.NODE_ENV === 'development' ? errorText : undefined
      });
    }

    const data = await response.json();
    if (data.status !== 'OK' || !data.result) {
      return res.status(502).json({
        message: 'Errore da Google Places details',
        error: process.env.NODE_ENV === 'development' ? data.error_message || data.status : undefined
      });
    }

    const addressComponents = Array.isArray(data.result.address_components)
      ? data.result.address_components
      : [];

    const preferredTypes = ['locality', 'postal_town', 'administrative_area_level_3', 'administrative_area_level_2'];
    let city = '';
    for (const type of preferredTypes) {
      const match = addressComponents.find((component) =>
        Array.isArray(component.types) && component.types.includes(type)
      );
      if (match?.long_name) {
        city = match.long_name;
        break;
      }
    }

    const mapsUrl = data.result.url || `https://www.google.com/maps/place/?q=place_id:${encodeURIComponent(placeId)}`;

    return res.json({
      placeId,
      name: data.result.name || '',
      city,
      mapsUrl
    });
  } catch (error) {
    return res.status(500).json({
      message: 'Errore nel recupero dettagli Google Places',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
});

// Summarize restaurant feedback with Gemini
router.post('/:id/feedback-summary', writeLimiter, authenticate, async (req, res) => {
  try {
    const geminiApiKey = process.env.GEMINI_API_KEY;
    if (!geminiApiKey) {
      return res.status(500).json({
        message: 'GEMINI_API_KEY non configurata sul backend'
      });
    }

    const restaurant = await Restaurant.findById(req.params.id).select('_id name cuisine address');
    if (!restaurant) {
      return res.status(404).json({ message: 'Restaurant not found' });
    }

    const reviews = await Review.find({ restaurant: restaurant._id })
      .populate('user', 'username displayName')
      .sort({ createdAt: -1 });

    if (!reviews.length) {
      return res.status(400).json({
        message: 'Nessuna recensione disponibile per generare il riassunto'
      });
    }

    const compactReviews = reviews.map((review) => {
      const user = review.user || {};
      const author = user.displayName || user.username || 'Utente';
      return {
        autore: author,
        servizio: review.serviceRating,
        prezzo: review.priceRating,
        menu: review.menuRating,
        commento: review.comment,
        data: review.createdAt
      };
    });

    const prompt = [
      'Riassumi le recensioni in italiano con tono informale e simpatico, senza battute.',
      'Rispondi con massimo 2 frasi semplici e chiare.',
      'Dai un feedback generico sul locale basato solo sui dati forniti.',
      'Non usare elenco puntato, non usare markdown, non inventare informazioni.',
      '',
      `Ristorante: ${restaurant.name}${restaurant.cuisine ? ` (${restaurant.cuisine})` : ''}${restaurant.address ? ` - ${restaurant.address}` : ''}`,
      `Recensioni analizzate: ${compactReviews.length}`,
      '',
      'Recensioni (JSON):',
      JSON.stringify(compactReviews)
    ].join('\n');

    let geminiResult;
    let geminiError;

    try {
      geminiResult = await generateGeminiContent({
        contents: prompt,
        models: [
          process.env.GEMINI_SUMMARY_MODEL || 'gemini-2.5-flash',
          'gemini-3.7-flash'
        ],
        config: {
          maxOutputTokens: 220,
          thinkingConfig: { thinkingLevel: 'low' }
        }
      });
    } catch (error) {
      geminiError = error;
    }

    if (!geminiResult) {
      const errorStatus = Number(geminiError?.status || geminiError?.code || 500);
      const errorText = geminiError?.message || String(geminiError || 'Errore Gemini');

      if (errorStatus === 429) {
        return res.status(429).json({
          message: 'Hai raggiunto il limite richieste AI del momento. Riprova tra qualche minuto.'
        });
      }

      if ([408, 503, 504].includes(errorStatus)) {
        return res.status(503).json({
          message: 'Gemini non ha risposto in tempo. Riprova tra poco.',
          error: process.env.NODE_ENV === 'development' ? errorText : undefined
        });
      }

      return res.status(502).json({
        message: 'Il servizio AI non è disponibile al momento. Riprova più tardi.',
        error: process.env.NODE_ENV === 'development' ? errorText : undefined
      });
    }

    const rawSummary = geminiResult.response?.text?.trim();

    const summary = (() => {
      if (!rawSummary) return '';
      const normalized = rawSummary.replace(/\s+/g, ' ').trim();
      const sentences = normalized.match(/[^.!?]+[.!?]+/g) || [];
      if (sentences.length >= 2) {
        return `${sentences[0].trim()} ${sentences[1].trim()}`;
      }
      if (sentences.length === 1) {
        return sentences[0].trim();
      }
      const chunks = normalized.split('.').map((s) => s.trim()).filter(Boolean);
      return chunks.slice(0, 2).join('. ') + (chunks.length ? '.' : '');
    })();

    if (!summary) {
      return res.status(502).json({
        message: 'Risposta Gemini non valida'
      });
    }

    res.json({
      model: geminiResult.model,
      restaurantId: restaurant._id,
      reviewCount: compactReviews.length,
      summary,
      generatedAt: new Date().toISOString()
    });
  } catch (error) {
    console.error('[feedback-summary] Error:', error.message);
    res.status(500).json({
      message: 'Non riusciamo a generare il riassunto al momento. Riprova tra poco!',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
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
    const { name, description, address, cuisine, coverImageUrl, googleMapsUrl, instagramUrl } = req.body;
    
    // Validate input
    if (!name) {
      return res.status(400).json({ message: 'Restaurant name is required' });
    }
    
    const restaurant = new Restaurant({
      name,
      description,
      address,
      cuisine,
      coverImageUrl,
      googleMapsUrl,
      instagramUrl,
      createdBy: req.user.userId
    });
    
    await restaurant.save();
    
    await restaurant.populate('createdBy', 'username email displayName');

    // Send push notifications to all subscribers (non-blocking)
    sendPushToAll({
      title: 'Nuovo luogo aggiunto!',
      body: `Ora puoi recensire "${name}"!`,
      url: `/restaurants/${restaurant._id}`
    }).catch(err => console.error('[push] Errore invio notifica nuovo luogo:', err.message));

    res.status(201).json({
      message: 'Restaurant created successfully',
      restaurant
    });
  } catch (error) {
    if (error.name === 'ValidationError') {
      const firstError = Object.values(error.errors || {})[0];
      return res.status(400).json({
        message: firstError?.message || 'Invalid restaurant data'
      });
    }
    res.status(500).json({ 
      message: 'Error creating restaurant', 
      error: error.message 
    });
  }
});

/**
 * @swagger
 * /api/restaurants/batch:
 *   post:
 *     summary: Create multiple restaurants (admin/superadmin only)
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
 *               - restaurants
 *             properties:
 *               restaurants:
 *                 type: array
 *                 items:
 *                   type: object
 *                   required:
 *                     - name
 *                   properties:
 *                     name:
 *                       type: string
 *                     description:
 *                       type: string
 *                     address:
 *                       type: string
 *                     cuisine:
 *                       type: string
 *     responses:
 *       201:
 *         description: Restaurants created successfully
 *       400:
 *         description: Invalid input
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Forbidden - admin role required
 */
// Create multiple restaurants (admin and superadmin only) - Apply write rate limiting
router.post('/batch', writeLimiter, authenticate, authorize('admin', 'superadmin'), async (req, res) => {
  try {
    const { restaurants } = req.body;
    
    // Validate input
    if (!restaurants || !Array.isArray(restaurants) || restaurants.length === 0) {
      return res.status(400).json({ message: 'Restaurants array is required and must not be empty' });
    }
    
    // Validate each restaurant
    for (const rest of restaurants) {
      if (!rest.name) {
        return res.status(400).json({ message: 'All restaurants must have a name' });
      }
    }
    
    // Create all restaurants
    const createdRestaurants = [];
    const errors = [];
    
    for (const restData of restaurants) {
      try {
        const restaurant = new Restaurant({
          name: restData.name,
          description: restData.description,
          address: restData.address,
          cuisine: restData.cuisine,
          coverImageUrl: restData.coverImageUrl,
          googleMapsUrl: restData.googleMapsUrl,
          instagramUrl: restData.instagramUrl,
          createdBy: req.user.userId
        });
        
        await restaurant.save();
        await restaurant.populate('createdBy', 'username email displayName');
        
        createdRestaurants.push(restaurant);
      } catch (error) {
        errors.push({
          restaurant: restData.name,
          error: error.message
        });
      }
    }
    
    res.status(201).json({
      message: `${createdRestaurants.length} restaurants created successfully`,
      created: createdRestaurants.length,
      failed: errors.length,
      restaurants: createdRestaurants,
      errors: errors.length > 0 ? errors : undefined
    });
  } catch (error) {
    res.status(500).json({ 
      message: 'Error creating restaurants', 
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
    const { name, description, address, cuisine, coverImageUrl, googleMapsUrl, instagramUrl } = req.body;
    
    const restaurant = await Restaurant.findById(req.params.id);
    
    if (!restaurant) {
      return res.status(404).json({ message: 'Restaurant not found' });
    }
    
    // Update only fields explicitly present in request payload.
    // This allows clearing optional values (e.g. description) during edit.
    if (Object.prototype.hasOwnProperty.call(req.body, 'name')) {
      restaurant.name = name;
    }
    if (Object.prototype.hasOwnProperty.call(req.body, 'description')) {
      restaurant.description = description;
    }
    if (Object.prototype.hasOwnProperty.call(req.body, 'address')) {
      restaurant.address = address;
    }
    if (Object.prototype.hasOwnProperty.call(req.body, 'cuisine')) {
      restaurant.cuisine = cuisine;
    }
    if (Object.prototype.hasOwnProperty.call(req.body, 'coverImageUrl')) {
      restaurant.coverImageUrl = coverImageUrl;
    }
    if (Object.prototype.hasOwnProperty.call(req.body, 'googleMapsUrl')) {
      restaurant.googleMapsUrl = googleMapsUrl;
    }
    if (Object.prototype.hasOwnProperty.call(req.body, 'instagramUrl')) {
      restaurant.instagramUrl = instagramUrl;
    }
    
    await restaurant.save();
    
    await restaurant.populate('createdBy', 'username email displayName');
    
    res.json({
      message: 'Ristorante aggiornato con successo',
      restaurant
    });
  } catch (error) {
    if (error.kind === 'ObjectId') {
      return res.status(404).json({ message: 'Restaurant not found' });
    }
    if (error.name === 'ValidationError') {
      const firstError = Object.values(error.errors || {})[0];
      return res.status(400).json({
        message: firstError?.message || 'Invalid restaurant data'
      });
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
router.delete('/:id', writeLimiter, authenticate, async (req, res) => {
  try {
    const restaurant = await Restaurant.findById(req.params.id);
    
    if (!restaurant) {
      return res.status(404).json({ message: 'Ristorante non trovato' });
    }
    
    // Check if user is the creator or has admin/superadmin role
    const isCreator = restaurant.createdBy.toString() === req.user.userId.toString();
    const isAdminOrSuperadmin = ['admin', 'superadmin'].includes(req.user.role);
    
    if (!isCreator && !isAdminOrSuperadmin) {
      return res.status(403).json({ 
        message: 'You can only delete restaurants you created' 
      });
    }
    
    // Delete all reviews associated with this restaurant
    const Review = require('../models/Review');
    await Review.deleteMany({ restaurant: req.params.id });
    
    // Delete the restaurant
    await Restaurant.findByIdAndDelete(req.params.id);
    
    res.json({ message: 'Ristorante eliminato con successo' });
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
