const express = require('express');
const { fetchRates } = require('../services/currencyService');
const { authMiddleware } = require('../middleware/auth');

const router = express.Router();
router.use(authMiddleware);

const SUPPORTED_CURRENCIES = [
  { code: 'ILS', name: 'Israeli Shekel', symbol: '₪' },
  { code: 'USD', name: 'US Dollar', symbol: '$' },
  { code: 'EUR', name: 'Euro', symbol: '€' },
  { code: 'GBP', name: 'British Pound', symbol: '£' },
  { code: 'JPY', name: 'Japanese Yen', symbol: '¥' },
  { code: 'CAD', name: 'Canadian Dollar', symbol: 'C$' },
  { code: 'AUD', name: 'Australian Dollar', symbol: 'A$' },
  { code: 'CHF', name: 'Swiss Franc', symbol: 'CHF' },
];

router.get('/rates', async (req, res) => {
  try {
    const base = req.query.base || 'ILS';
    const data = await fetchRates(base);
    res.json(data);
  } catch (err) {
    console.error('Currency rates error:', err);
    res.status(500).json({ error: 'Failed to fetch rates' });
  }
});

router.get('/supported', (_req, res) => {
  res.json({ currencies: SUPPORTED_CURRENCIES });
});

module.exports = router;
