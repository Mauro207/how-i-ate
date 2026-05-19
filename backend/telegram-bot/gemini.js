const { GoogleGenerativeAI } = require('@google/generative-ai');

const MODEL_NAME = 'gemini-2.5-flash-lite-preview-06-17';

let model;

const getModel = () => {
  if (model) {
    return model;
  }

  if (!process.env.GEMINI_API_KEY) {
    throw new Error('Missing GEMINI_API_KEY in environment');
  }

  const client = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
  model = client.getGenerativeModel({ model: MODEL_NAME });
  return model;
};

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

const extractIntent = async (messageText) => {
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

  const aiModel = getModel();
  const result = await aiModel.generateContent({
    contents: [{ role: 'user', parts: [{ text: prompt }] }],
    generationConfig: {
      temperature: 0.1,
      responseMimeType: 'application/json'
    }
  });

  const text = result?.response?.text?.() || '';
  const parsed = parseJsonBlock(text) || {};

  return {
    city: typeof parsed.city === 'string' && parsed.city.trim() ? parsed.city.trim() : null,
    placeType: typeof parsed.placeType === 'string' && parsed.placeType.trim() ? parsed.placeType.trim() : null,
    searchText: typeof parsed.searchText === 'string' && parsed.searchText.trim()
      ? parsed.searchText.trim().slice(0, 60)
      : messageText.trim().slice(0, 60)
  };
};

const buildFallbackRecommendation = ({ city, placeType, candidates }) => {
  const best = candidates[0];
  const where = city ? ` a ${city}` : '';
  const what = placeType ? ` per ${placeType}` : '';

  const lines = [
    `Ho trovato questo posto top${where}${what}:`,
    '',
    `*${best.name}*`,
    `- Voto medio: ${best.averageRating.toFixed(1)}/10 (${best.reviewCount} recensioni)`,
    best.cuisine ? `- Tipologia: ${best.cuisine}` : null,
    best.address ? `- Indirizzo: ${best.address}` : null,
    best.googleMapsUrl ? `- Maps: ${best.googleMapsUrl}` : null,
    '',
    'Se vuoi posso proporti anche un paio di alternative.'
  ].filter(Boolean);

  return lines.join('\n');
};

const generateRecommendation = async ({ originalMessage, city, placeType, candidates }) => {
  if (!Array.isArray(candidates) || candidates.length === 0) {
    return {
      bestIndex: -1,
      replyMarkdown: 'Non ho trovato risultati utili. Prova con una citta o un tipo di locale piu specifico 🙂'
    };
  }

  const shortlist = candidates.slice(0, 6).map((candidate, index) => ({
    index,
    name: candidate.name,
    address: candidate.address || null,
    cuisine: candidate.cuisine || null,
    averageRating: Number(candidate.averageRating || 0),
    reviewCount: Number(candidate.reviewCount || 0),
    googleMapsUrl: candidate.googleMapsUrl || null,
    instagramUrl: candidate.instagramUrl || null
  }));

  const prompt = [
    'Sei un assistente food advisor per Telegram.',
    'Scegli il miglior locale tra i candidati, tenendo conto soprattutto di voto medio e numero recensioni,',
    'ma anche della coerenza con la richiesta utente.',
    'Rispondi SOLO JSON valido con chiavi:',
    '{"bestIndex":number,"replyMarkdown":"string"}',
    'Regole replyMarkdown:',
    '- Lingua italiana',
    '- Tono friendly',
    '- Usa 2-4 emoji max',
    '- Formato Markdown semplice (compatibile Telegram)',
    '- Max 8 righe',
    '- Cita nome locale, motivo scelta, voto medio, recensioni, indirizzo se presente, link Maps se presente',
    '- Non inventare dati',
    '',
    `Richiesta utente: ${originalMessage}`,
    `Citta estratta: ${city || 'non specificata'}`,
    `Tipo locale estratto: ${placeType || 'non specificato'}`,
    '',
    `Candidati: ${JSON.stringify(shortlist)}`
  ].join('\n');

  try {
    const aiModel = getModel();
    const result = await aiModel.generateContent({
      contents: [{ role: 'user', parts: [{ text: prompt }] }],
      generationConfig: {
        temperature: 0.35,
        responseMimeType: 'application/json'
      }
    });

    const text = result?.response?.text?.() || '';
    const parsed = parseJsonBlock(text) || {};
    const bestIndex = Number.isInteger(parsed.bestIndex) ? parsed.bestIndex : 0;
    const chosen = shortlist[bestIndex] ? bestIndex : 0;

    if (typeof parsed.replyMarkdown === 'string' && parsed.replyMarkdown.trim()) {
      return {
        bestIndex: chosen,
        replyMarkdown: parsed.replyMarkdown.trim()
      };
    }
  } catch (_) {
    // Fallback below keeps the bot responsive even if AI formatting fails.
  }

  return {
    bestIndex: 0,
    replyMarkdown: buildFallbackRecommendation({ city, placeType, candidates: shortlist })
  };
};

module.exports = {
  MODEL_NAME,
  extractIntent,
  generateRecommendation
};
