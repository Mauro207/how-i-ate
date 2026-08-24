let geminiClient;

const DEFAULT_GEMINI_MODEL = 'gemini-3.7-flash';
const DEFAULT_MODEL_TIMEOUT_MS = 10000;
const GEMINI_MODEL_CANDIDATES = [
  process.env.GEMINI_MODEL,
  DEFAULT_GEMINI_MODEL,
  'gemini-2.5-flash',
  'gemini-3.6-flash'
].filter((model, index, models) => model && models.indexOf(model) === index);

let selectedGeminiModel = GEMINI_MODEL_CANDIDATES[0];

const configuredTimeout = Number.parseInt(process.env.GEMINI_MODEL_TIMEOUT_MS, 10);
const modelTimeoutMs = Number.isFinite(configuredTimeout) && configuredTimeout >= 10000
  ? configuredTimeout
  : DEFAULT_MODEL_TIMEOUT_MS;

const getGeminiClient = () => {
  if (!geminiClient) {
    const { GoogleGenAI } = require('@google/genai');
    geminiClient = new GoogleGenAI({ apiKey: process.env.GEMINI_API_KEY });
  }

  return geminiClient;
};

const isFallbackEligibleError = (error) => {
  const message = String(error?.message || '');
  const status = Number(error?.status || error?.code);

  return [404, 408, 500, 502, 503, 504].includes(status)
    || /not found|deadline|timeout|timed out|fetch failed/i.test(message);
};

const generateContent = async ({ contents, config, models }) => {
  const client = getGeminiClient();
  let lastError;
  const requestedModels = Array.isArray(models)
    ? models.filter((model, index) => model && models.indexOf(model) === index)
    : [];
  const candidates = requestedModels.length
    ? requestedModels
    : [
        selectedGeminiModel,
        ...GEMINI_MODEL_CANDIDATES.filter((model) => model !== selectedGeminiModel)
      ];

  for (const model of candidates) {
    try {
      const modelConfig = { ...config };
      if (model.startsWith('gemini-2.5-')) {
        modelConfig.thinkingConfig = { thinkingBudget: 0 };
      }

      const response = await client.models.generateContent({
        model,
        contents,
        config: {
          ...modelConfig,
          httpOptions: {
            ...modelConfig.httpOptions,
            timeout: modelTimeoutMs
          }
        }
      });

      if (model !== candidates[0]) {
        console.log(`[gemini] Modello fallback attivo: ${model}`);
      }

      if (!requestedModels.length) {
        selectedGeminiModel = model;
      }
      return { response, model };
    } catch (error) {
      lastError = error;

      if (!isFallbackEligibleError(error)) {
        throw error;
      }

      console.warn(`[gemini] ${model} non disponibile (${error?.status || error?.code || 'timeout'}), provo il fallback`);
    }
  }

  throw lastError || new Error('Nessun modello Gemini disponibile tra i candidati configurati');
};

module.exports = {
  DEFAULT_GEMINI_MODEL,
  DEFAULT_MODEL_TIMEOUT_MS,
  generateContent
};
