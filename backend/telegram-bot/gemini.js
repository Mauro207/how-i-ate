const MODEL_NAME = 'deterministic-intent-parser';
const { generateContent } = require('../services/gemini');

const PLACE_TYPE_PATTERNS = [
  { type: 'ristorante giapponese', patterns: [/\bristorante\s+giapponese\b/i] },
  { type: 'ristorante cinese', patterns: [/\bristorante\s+cinese\b/i] },
  { type: 'hamburger', patterns: [/\bhamburger(?:eria)?\b/i, /\bburger(?:eria)?\b/i] },
  { type: 'pizzeria', patterns: [/\bpizz(?:a|eria|erie|e)\b/i] },
  { type: 'sushi', patterns: [/\bsushi\b/i, /\bjapanese\b/i, /\bg(i|ii)appones[ei]\b/i] },
  { type: 'pub', patterns: [/\bpub\b/i, /\bbirreria\b/i, /\bbrewpub\b/i] },
  { type: 'trattoria', patterns: [/\btrattoria\b/i, /\bosteria\b/i] },
  { type: 'braceria', patterns: [/\bbraceria\b/i, /\bgriglieria\b/i, /\bsteak\s*house\b/i] },
  { type: 'ristorante', patterns: [/\bristorante\b/i, /\blocale\b/i, /\blocali\b/i] },
  { type: 'bar', patterns: [/\bbar\b/i, /\bcaff[eè]\b/i, /\bbistrot\b/i] },
  { type: 'gelateria', patterns: [/\bgelateria\b/i, /\bgelato\b/i] },
  { type: 'pasticceria', patterns: [/\bpasticceria\b/i, /\bdolci\b/i, /\bcornetti\b/i] },
  { type: 'paninoteca', patterns: [/\bpaninoteca\b/i, /\bpanino\b/i, /\bpanini\b/i] },
  { type: 'pesce', patterns: [/\bpesce\b/i, /\bseafood\b/i] },
  { type: 'carne', patterns: [/\bcarne\b/i, /\bgriglia\b/i] },
  { type: 'pizza al taglio', patterns: [/\bpizza\s+al\s+taglio\b/i] },
  { type: 'aperitivo', patterns: [/\baperitivo\b/i, /\bapericena\b/i] },
  { type: 'brunch', patterns: [/\bbrunch\b/i] }
];

const CITY_PREPOSITIONS = [
  'vicino a',
  'nei pressi di',
  'nei pressi del',
  'nei pressi della',
  'zona',
  'a',
  'ad',
  'in',
  'da',
  'nel',
  'nella',
  'nei',
  'nelle',
  'su'
];

const CITY_STOP_WORDS = new Set([
  'oggi', 'stasera', 'domani', 'adesso', 'subito', 'buono', 'buona', 'buoni', 'buone',
  'top', 'economico', 'economica', 'economici', 'economiche', 'migliore', 'migliori',
  'dove', 'trovo', 'cerco', 'consigliami', 'consigliami', 'consiglia', 'vorrei', 'voglio',
  'un', 'una', 'uno', 'dei', 'delle', 'del', 'della', 'di', 'per', 'con', 'senza', 'il', 'la', 'lo'
]);

const DESCRIPTOR_WORDS = new Set([
  'economico', 'economica', 'economici', 'economiche', 'romantico', 'romantica', 'romantici', 'romantiche',
  'buono', 'buona', 'buoni', 'buone', 'ottimo', 'ottima', 'ottimi', 'ottime', 'migliore', 'migliori',
  'vegano', 'vegana', 'vegani', 'vegane', 'veloce', 'veloci', 'tranquillo', 'tranquilla', 'tranquilli', 'tranquille'
]);

const ITALIAN_LOWERCASE_PARTICLES = new Set(['di', 'del', 'della', 'dello', 'dei', 'degli', 'delle', 'da', 'de', 'san', 'sant', 'santa']);

const REQUEST_PREFIXES = [
  /^ciao\s+/i,
  /^hey\s+/i,
  /^ehi\s+/i,
  /^cerco\s+/i,
  /^sto cercando\s+/i,
  /^mi trovi\s+/i,
  /^mi trovi una?\s+/i,
  /^mi consigli\s+/i,
  /^consigliami\s+/i,
  /^vorrei\s+/i,
  /^voglio\s+/i,
  /^dove mangiare\s+/i,
  /^dove posso mangiare\s+/i,
  /^mi suggerisci\s+/i
];

const normalizeText = (value) => (value || '')
  .toString()
  .normalize('NFD')
  .replace(/[\u0300-\u036f]/g, '')
  .replace(/[“”"'`]/g, ' ')
  .replace(/[!?.,;:()\[\]{}]/g, ' ')
  .replace(/\s+/g, ' ')
  .trim();

const toTitleCase = (value) => value
  .split(/\s+/)
  .filter(Boolean)
  .map((token, index) => {
    const lower = token.toLowerCase();
    if (index > 0 && ITALIAN_LOWERCASE_PARTICLES.has(lower)) {
      return lower;
    }

    return lower.charAt(0).toUpperCase() + lower.slice(1);
  })
  .join(' ');

const cleanupCity = (value) => {
  if (!value) {
    return null;
  }

  const cleaned = normalizeText(value)
    .replace(/^(di|del|della|dello|dei|degli|delle)\s+/i, '')
    .replace(/\b(?:centro|provincia|zona|quartiere)\b/gi, ' ')
    .replace(/\s+/g, ' ')
    .trim();

  if (!cleaned) {
    return null;
  }

  const tokens = cleaned.split(' ').filter((token) => {
    const lower = token.toLowerCase();
    return !CITY_STOP_WORDS.has(lower) || ITALIAN_LOWERCASE_PARTICLES.has(lower);
  });
  if (!tokens.length) {
    return null;
  }

  return toTitleCase(tokens.join(' '));
};

const detectPlaceType = (messageText) => {
  for (const entry of PLACE_TYPE_PATTERNS) {
    if (entry.patterns.some((pattern) => pattern.test(messageText))) {
      return entry.type;
    }
  }

  return null;
};

const detectCityFromPreposition = (messageText) => {
  for (const preposition of CITY_PREPOSITIONS) {
    const pattern = new RegExp(`\\b${preposition.replace(/\s+/g, '\\s+')}\\s+([a-zA-ZÀ-ÿ][a-zA-ZÀ-ÿ' -]{1,40})$`, 'i');
    const match = messageText.match(pattern);

    if (match?.[1]) {
      const city = cleanupCity(match[1]);
      if (city) {
        return city;
      }
    }
  }

  return null;
};

const stripKnownPlaceType = (messageText) => {
  let stripped = messageText;

  for (const entry of PLACE_TYPE_PATTERNS) {
    for (const pattern of entry.patterns) {
      stripped = stripped.replace(pattern, ' ');
    }
  }

  return stripped.replace(/\s+/g, ' ').trim();
};

const detectTrailingCity = (messageText, placeType) => {
  let stripped = stripKnownPlaceType(messageText);

  for (const prefix of REQUEST_PREFIXES) {
    stripped = stripped.replace(prefix, '');
  }

  stripped = stripped
    .replace(/\b(?:buona?|buoni|buone|top|economica?|economici|economiche|migliore|migliori)\b/gi, ' ')
    .replace(/\s+/g, ' ')
    .trim();

  if (!stripped) {
    return null;
  }

  const prepositionCity = detectCityFromPreposition(stripped);
  if (prepositionCity) {
    return prepositionCity;
  }

  const tokens = stripped
    .split(' ')
    .filter(Boolean)
    .filter((token) => !DESCRIPTOR_WORDS.has(token.toLowerCase()));

  if (placeType) {
    if (tokens.length >= 1 && tokens.length <= 4) {
      return cleanupCity(tokens.join(' '));
    }
  }

  if (!placeType && tokens.length >= 1 && tokens.length <= 4) {
    return cleanupCity(tokens.join(' '));
  }

  return null;
};

const buildSearchText = ({ originalMessage, city, placeType }) => {
  const fallback = normalizeText(originalMessage).slice(0, 60);
  const compact = [placeType, city].filter(Boolean).join(' ').trim();
  return (compact || fallback).slice(0, 60);
};

const canUseGeminiFallback = () => Boolean(process.env.GEMINI_API_KEY);

const parseJsonBlock = (rawText) => {
  if (!rawText) {
    return null;
  }

  const cleaned = rawText
    .replace(/^```json\s*/i, '')
    .replace(/^```\s*/i, '')
    .replace(/```$/i, '')
    .trim();

  try {
    return JSON.parse(cleaned);
  } catch {
    const start = cleaned.indexOf('{');
    const end = cleaned.lastIndexOf('}');

    if (start === -1 || end === -1 || end <= start) {
      return null;
    }

    try {
      return JSON.parse(cleaned.slice(start, end + 1));
    } catch {
      return null;
    }
  }
};

const extractIntentWithGemini = async (messageText) => {
  const prompt = [
    'Estrai intento da una richiesta utente su ristoranti in Italia.',
    'Rispondi SOLO JSON valido con queste chiavi:',
    '{"city":"string|null","placeType":"string|null","searchText":"string"}',
    'Regole:',
    '- city: citta se presente (es. Napoli, Benevento), altrimenti null',
    '- placeType: tipo locale/cucina (es. pizzeria, sushi, pub), altrimenti null',
    '- searchText: query utile sintetica (max 60 caratteri)',
    'Non aggiungere testo extra.',
    '',
    `Messaggio utente: ${messageText}`
  ].join('\n');

  const { response } = await generateContent({
    contents: [{ role: 'user', parts: [{ text: prompt }] }],
    config: {
      responseMimeType: 'application/json',
      thinkingConfig: { thinkingLevel: 'low' }
    }
  });

  const text = response?.text || '';
  const parsed = parseJsonBlock(text) || {};

  return {
    city: typeof parsed.city === 'string' && parsed.city.trim() ? parsed.city.trim() : null,
    placeType: typeof parsed.placeType === 'string' && parsed.placeType.trim() ? parsed.placeType.trim() : null,
    searchText: typeof parsed.searchText === 'string' && parsed.searchText.trim()
      ? parsed.searchText.trim().slice(0, 60)
      : normalizeText(messageText).slice(0, 60)
  };
};

const extractIntent = async (messageText) => {
  const normalizedMessage = normalizeText(messageText);
  const placeType = detectPlaceType(normalizedMessage);
  const city = detectCityFromPreposition(normalizedMessage) || detectTrailingCity(normalizedMessage, placeType);

  if (!city && !placeType && canUseGeminiFallback()) {
    try {
      return await extractIntentWithGemini(messageText);
    } catch (error) {
      console.error('[telegram-bot] Gemini fallback extractIntent failed:', error.message);
    }
  }

  return {
    city,
    placeType,
    searchText: buildSearchText({
      originalMessage: messageText,
      city,
      placeType
    })
  };
};

module.exports = {
  MODEL_NAME,
  extractIntent
};
