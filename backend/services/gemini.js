let geminiClient;

const DEFAULT_GEMINI_MODEL = 'gemini-3.7-flash';
const GEMINI_MODEL_CANDIDATES = [
  process.env.GEMINI_MODEL,
  DEFAULT_GEMINI_MODEL,
  'gemini-3.6-flash',
  'gemini-2.5-flash'
].filter((model, index, models) => model && models.indexOf(model) === index);

let selectedGeminiModel = GEMINI_MODEL_CANDIDATES[0];

const getGeminiClient = () => {
  if (!geminiClient) {
    const { GoogleGenAI } = require('@google/genai');
    geminiClient = new GoogleGenAI({ apiKey: process.env.GEMINI_API_KEY });
  }

  return geminiClient;
};

const isModelNotFoundError = (error) => {
  const message = String(error?.message || '');
  return error?.status === 404 || message.includes('404') || message.includes('not found');
};

const generateContent = async ({ contents, config }) => {
  const client = getGeminiClient();
  const candidates = [
    selectedGeminiModel,
    ...GEMINI_MODEL_CANDIDATES.filter((model) => model !== selectedGeminiModel)
  ];

  for (const model of candidates) {
    try {
      const response = await client.models.generateContent({ model, contents, config });

      if (model !== selectedGeminiModel) {
        console.log(`[gemini] Modello fallback attivo: ${model}`);
      }

      selectedGeminiModel = model;
      return { response, model };
    } catch (error) {
      if (!isModelNotFoundError(error)) {
        throw error;
      }
    }
  }

  throw new Error('Nessun modello Gemini disponibile tra i candidati configurati');
};

module.exports = {
  DEFAULT_GEMINI_MODEL,
  generateContent
};
