let cachedRates = null;
let cacheTimestamp = 0;
const CACHE_DURATION = 24 * 60 * 60 * 1000; // 24 hours

const FALLBACK_RATES = {
  ILS: 1,
  USD: 0.27,
  EUR: 0.25,
  GBP: 0.21,
  JPY: 40.5,
  CAD: 0.37,
  AUD: 0.42,
  CHF: 0.24,
};

async function fetchRates(base = 'ILS') {
  const now = Date.now();
  if (cachedRates && cachedRates.base === base && now - cacheTimestamp < CACHE_DURATION) {
    return cachedRates;
  }

  try {
    const apiKey = process.env.EXCHANGE_RATE_API_KEY;
    if (!apiKey) {
      return { base, rates: FALLBACK_RATES, source: 'fallback' };
    }

    const response = await fetch(
      `https://v6.exchangerate-api.com/v6/${apiKey}/latest/${base}`
    );
    const data = await response.json();

    if (data.result === 'success') {
      cachedRates = { base, rates: data.conversion_rates, source: 'api' };
      cacheTimestamp = now;
      return cachedRates;
    }

    return { base, rates: FALLBACK_RATES, source: 'fallback' };
  } catch {
    return { base, rates: FALLBACK_RATES, source: 'fallback' };
  }
}

module.exports = { fetchRates };
