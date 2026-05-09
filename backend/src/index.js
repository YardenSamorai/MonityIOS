require('dotenv').config();
const express = require('express');
const cors = require('cors');
const sequelize = require('./config/database');
require('./models');

const authRoutes = require('./routes/auth');
const transactionRoutes = require('./routes/transactions');
const categoryRoutes = require('./routes/categories');
const budgetRoutes = require('./routes/budgets');
const recurringRoutes = require('./routes/recurring');
const exportRoutes = require('./routes/export');
const currencyRoutes = require('./routes/currencies');
const creditCardRoutes = require('./routes/creditCards');
const householdRoutes = require('./routes/household');
const { startRecurringJob } = require('./services/recurringService');

const app = express();
const PORT = process.env.PORT || 3000;
const IS_PRODUCTION = process.env.NODE_ENV === 'production';

const allowedOrigins = (process.env.CORS_ORIGINS || '').split(',').map(s => s.trim()).filter(Boolean);
app.use(cors({
  origin: (origin, callback) => {
    if (!origin) return callback(null, true);
    if (!IS_PRODUCTION) return callback(null, true);
    if (allowedOrigins.length === 0) return callback(null, true);
    if (allowedOrigins.includes(origin)) return callback(null, true);
    callback(new Error('Not allowed by CORS'));
  },
  credentials: true,
}));
app.use(express.json());

app.get('/api/health', (_req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

app.use('/api/auth', authRoutes);
app.use('/api/transactions', transactionRoutes);
app.use('/api/categories', categoryRoutes);
app.use('/api/budgets', budgetRoutes);
app.use('/api/recurring', recurringRoutes);
app.use('/api/export', exportRoutes);
app.use('/api/currencies', currencyRoutes);
app.use('/api/credit-cards', creditCardRoutes);
app.use('/api/household', householdRoutes);

app.use((err, _req, res, _next) => {
  console.error(err.stack);
  res.status(500).json({ error: 'Internal server error' });
});

async function start() {
  try {
    await sequelize.authenticate();
    console.log('Database connected');

    const skipAlter = process.env.DB_NO_ALTER === 'true';
    if (skipAlter) {
      await sequelize.sync();
      console.log('Models synchronized (safe mode, no alter)');
    } else {
      if (IS_PRODUCTION) {
        console.warn('WARNING: running sequelize.sync({ alter: true }) in production. Set DB_NO_ALTER=true once schema is stable.');
      }
      await sequelize.query('PRAGMA foreign_keys = OFF;');
      await sequelize.sync({ alter: true });
      await sequelize.query('PRAGMA foreign_keys = ON;');
      console.log('Models synchronized (alter mode)');
    }

    try {
      const [results] = await sequelize.query(
        `UPDATE transactions SET is_billing_charge = 1
         WHERE is_billing_charge = 0
           AND credit_card_id IS NULL
           AND (note LIKE 'חיוב כרטיס%' OR note LIKE 'Bill%' OR note LIKE 'Card charge%')`
      );
      console.log('Backfill: marked old billing charge transactions');
    } catch (err) {
      console.warn('Backfill warning:', err.message);
    }

    startRecurringJob();

    app.listen(PORT, '0.0.0.0', () => {
      console.log(`Server running on port ${PORT}`);
    });
  } catch (err) {
    console.error('Failed to start server:', err);
    process.exit(1);
  }
}

start();
