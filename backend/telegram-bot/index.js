const TelegramBot = require('node-telegram-bot-api');
const { extractIntent } = require('./gemini');
const { findPlaces } = require('./placesService');
const { checkAndConsumeDailyRequest } = require('./usageService');

// dotenv is already loaded by backend/index.js before this module is required
const BOT_TOKEN = process.env.TELEGRAM_BOT_TOKEN;
const SESSION_TTL_MS = 15 * 60 * 1000;
const PUBLIC_APP_URL = 'https://how-i-ate.it';

if (!BOT_TOKEN) {
  throw new Error('Missing TELEGRAM_BOT_TOKEN in environment');
}

if (!process.env.GEMINI_API_KEY) {
  throw new Error('Missing GEMINI_API_KEY in environment');
}

const bot = new TelegramBot(BOT_TOKEN);
const sessions = new Map();
const processingChats = new Set();

const helpMessage = [
  '*How-I-Ate Bot* 🍽️',
  '',
  'Scrivimi una richiesta tipo:',
  '- Cerco una pizzeria a Benevento',
  '- sushi Napoli',
  '',
  'Ti rispondo con le *prime 3* opzioni nella citta/provincia indicata,',
  'ordinate per *media recensioni* dalla piu alta alla piu bassa.',
  '',
  'In alternativa usa il flusso guidato con /cerca.',
  'Puoi annullare in qualsiasi momento con /annulla'
].join('\n');

const buildRestaurantPageUrl = (restaurantId) => {
  const target = encodeURIComponent(`/restaurants/${restaurantId}`);
  return `${PUBLIC_APP_URL}/open-in-webapp?target=${target}`;
};

const buildTopThreeMessage = ({ city, placeType, places }) => {
  const locationLabel = city || 'zona richiesta';
  const typeLabel = placeType || 'locali';

  const lines = [
    `Ecco le *top 3* ${typeLabel} per *${locationLabel}* 🏆`,
    ''
  ];

  places.slice(0, 3).forEach((place, index) => {
    lines.push(`*${index + 1}\. ${place.name}*`);
    lines.push(`Media recensioni: *${place.averageRating.toFixed(1)}/10* \(${place.reviewCount} recensioni\)`);

    if (place.cuisine) {
      lines.push(`Tipologia: ${place.cuisine}`);
    }

    if (place.address) {
      lines.push(`Indirizzo: ${place.address}`);
    }

    if (place.googleMapsUrl) {
      lines.push(`Maps: ${place.googleMapsUrl}`);
    }

    lines.push(`Scheda completa: [Apri Link](${buildRestaurantPageUrl(place.id)})`);

    lines.push('');
  });

  lines.push('Se vuoi, posso cercare anche in un\'altra zona 🙂');
  return lines.join('\n');
};

const buildNearbyFallbackMessage = ({ city, placeType, places }) => {
  const locationLabel = city || 'la zona richiesta';
  const typeLabel = placeType || 'locali';

  const lines = [
    `Non ho trovato ${typeLabel} con recensioni per *${locationLabel}* 😕`,
    'Ti consiglio quindi le opzioni recensite *piu vicine* disponibili:',
    ''
  ];

  places.slice(0, 3).forEach((place, index) => {
    lines.push(`*${index + 1}\. ${place.name}*`);
    lines.push(`Media recensioni: *${place.averageRating.toFixed(1)}/10* \(${place.reviewCount} recensioni\)`);

    if (place.address) {
      lines.push(`Zona: ${place.address}`);
    }

    if (place.googleMapsUrl) {
      lines.push(`Maps: ${place.googleMapsUrl}`);
    }

    lines.push(`Scheda completa: [Apri Link](${buildRestaurantPageUrl(place.id)})`);

    lines.push('');
  });

  lines.push('Se vuoi, provo anche con un\'altra provincia vicina 👌');
  return lines.join('\n');
};

const now = () => Date.now();

const getSession = (chatId) => {
  const session = sessions.get(chatId);

  if (!session) {
    return null;
  }

  if (now() - session.updatedAt > SESSION_TTL_MS) {
    sessions.delete(chatId);
    return null;
  }

  return session;
};

const setSession = (chatId, data) => {
  sessions.set(chatId, {
    ...data,
    updatedAt: now()
  });
};

const clearSession = (chatId) => {
  sessions.delete(chatId);
};

const sendMarkdown = async (chatId, text) => {
  try {
    await bot.sendMessage(chatId, text, {
      parse_mode: 'Markdown',
      disable_web_page_preview: true
    });
  } catch {
    await bot.sendMessage(chatId, text.replace(/[*_`]/g, ''), {
      disable_web_page_preview: true
    });
  }
};

const runSearchFlow = async ({ chatId, userId, userMessage, forcedCity, forcedPlaceType }) => {
  if (processingChats.has(chatId)) {
    await sendMarkdown(
      chatId,
      'Sto ancora elaborando la richiesta precedente ⏳\nNon inviare altri messaggi: riceverai comunque la risposta appena pronta.'
    );
    return;
  }

  processingChats.add(chatId);

  try {
    const extracted = await extractIntent(userMessage);
    const city = forcedCity || extracted.city;
    const placeType = forcedPlaceType || extracted.placeType;
    const searchText = extracted.searchText || userMessage;

    // Se non riusciamo a ricavare ne localita ne tipologia, blocchiamo la ricerca.
    if (!city && !placeType) {
      await sendMarkdown(
        chatId,
        'Il messaggio non e corretto 😕\nScrivi almeno *tipologia* o *localita* \(meglio entrambe\).\nEsempio: *"Cerco una pizzeria a Benevento"*.'
      );
      return;
    }

    const usage = await checkAndConsumeDailyRequest({
      telegramUserId: String(userId || chatId)
    });

    if (!usage.allowed) {
      await sendMarkdown(
        chatId,
        `Hai raggiunto il limite giornaliero di *${usage.max}* richieste 🙏\nRiprova domani.`
      );
      return;
    }

    await sendMarkdown(
      chatId,
      `Richiesta ricevuta ✅\nSto cercando i risultati migliori \(${usage.remaining} richieste rimaste oggi\).\nNon inviare altri messaggi: ti rispondo appena pronto ⏳`
    );
    await bot.sendChatAction(chatId, 'typing');

    const { places, usedNearbyFallback } = await findPlaces({
      city,
      placeType,
      searchText,
      limit: 3
    });

    if (!places.length) {
      await sendMarkdown(
        chatId,
        'Non ho trovato locali in linea con la richiesta 😕\nProva a specificare meglio citta e tipologia (es: pizzeria Caserta).'
      );
      return;
    }

    if (usedNearbyFallback) {
      await sendMarkdown(chatId, buildNearbyFallbackMessage({ city, placeType, places }));
      return;
    }

    await sendMarkdown(chatId, buildTopThreeMessage({ city, placeType, places }));
  } finally {
    processingChats.delete(chatId);
  }
};

const handleMessage = async (msg) => {
  const chatId = msg.chat.id;
  const userId = msg.from?.id;
  const text = (msg.text || '').trim();

  if (!text) {
    return;
  }

  if (/^\/start$/i.test(text) || /^\/help$/i.test(text)) {
    await sendMarkdown(chatId, helpMessage);
    return;
  }

  if (/^\/annulla$/i.test(text)) {
    clearSession(chatId);
    await sendMarkdown(chatId, 'Ricerca guidata annullata. Quando vuoi, riparti con /cerca 👍');
    return;
  }

  if (/^\/cerca$/i.test(text)) {
    setSession(chatId, {
      mode: 'guided-search',
      step: 'city',
      city: null,
      placeType: null
    });

    await sendMarkdown(chatId, 'Perfetto! In quale citta stai cercando?');
    return;
  }

  if (text.startsWith('/')) {
    await sendMarkdown(chatId, 'Comando non riconosciuto. Usa /help per vedere i comandi disponibili.');
    return;
  }

  const session = getSession(chatId);

  try {
    if (session?.mode === 'guided-search') {
      if (session.step === 'city') {
        setSession(chatId, {
          ...session,
          step: 'placeType',
          city: text
        });

        await sendMarkdown(chatId, 'Ottimo! Che tipo di locale vuoi? (es: pizzeria, sushi, pub)\nPuoi anche scrivere "salta".');
        return;
      }

      if (session.step === 'placeType') {
        const placeType = /^salta$/i.test(text) ? null : text;
        const city = session.city;

        clearSession(chatId);

        const syntheticMessage = [placeType, city].filter(Boolean).join(' ');
        await runSearchFlow({
          chatId,
          userId,
          userMessage: syntheticMessage,
          forcedCity: city,
          forcedPlaceType: placeType
        });
        return;
      }
    }

    await runSearchFlow({
      chatId,
      userId,
      userMessage: text
    });
  } catch (error) {
    console.error('[telegram-bot] Error:', error.message);
    await sendMarkdown(chatId, 'Ops, qualcosa e andato storto durante la ricerca. Riprova tra poco 🙏');
  }
};

const processTelegramUpdate = async (update) => {
  if (!update?.message) {
    return;
  }

  await handleMessage(update.message);
};

bot.on('polling_error', (error) => {
  console.error('[telegram-bot] Polling error:', error.message);
});

module.exports = { bot, processTelegramUpdate };
