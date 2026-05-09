const express = require('express');
const { Op } = require('sequelize');
const { v4: uuidv4 } = require('uuid');
const sequelize = require('../config/database');
const { Transaction, Category, CreditCard } = require('../models');
const { authMiddleware } = require('../middleware/auth');
const { applyCategoryRules } = require('../services/categoryRulesService');

const router = express.Router();
router.use(authMiddleware);

async function ensureCategoryOwnership(categoryId, userId) {
  if (categoryId === undefined || categoryId === null) return true;
  const cat = await Category.findOne({ where: { id: categoryId, userId } });
  return !!cat;
}

async function ensureCreditCardOwnership(creditCardId, userId) {
  if (creditCardId === undefined || creditCardId === null) return true;
  const card = await CreditCard.findOne({ where: { id: creditCardId, userId } });
  return !!card;
}

function safeInt(v, fallback, min, max) {
  const n = parseInt(v, 10);
  if (!Number.isFinite(n)) return fallback;
  if (min !== undefined && n < min) return min;
  if (max !== undefined && n > max) return max;
  return n;
}

router.get('/', async (req, res) => {
  try {
    const { type, categoryId, from, to, q, page = 1, limit = 50 } = req.query;

    const baseUser = { userId: req.userId };
    const parts = [baseUser];

    if (type) parts.push({ type });
    if (categoryId) parts.push({ categoryId });
    if (req.query.creditCardId) parts.push({ creditCardId: req.query.creditCardId });
    if (from || to) {
      const dateClause = {};
      if (from) dateClause[Op.gte] = from;
      if (to) dateClause[Op.lte] = to;
      parts.push({ date: dateClause });
    }
    if (q && String(q).trim()) {
      const qt = String(q).trim().replace(/\\/g, '').replace(/[%_]/g, '');
      if (qt.length) {
        parts.push(sequelize.where(
          sequelize.fn('LOWER', sequelize.col('Transaction.note')),
          { [Op.like]: `%${qt.toLowerCase()}%` },
        ));
      }
    }

    const where = parts.length === 1 ? parts[0] : { [Op.and]: parts };

    const safePage = safeInt(page, 1, 1);
    const safeLimit = safeInt(limit, 50, 1, 200);
    const offset = (safePage - 1) * safeLimit;
    const { rows, count } = await Transaction.findAndCountAll({
      where,
      include: [
        { model: Category, attributes: ['id', 'name', 'nameHe', 'icon', 'color'] },
        { model: CreditCard, attributes: ['id', 'name', 'lastFourDigits', 'color'] },
      ],
      order: [['date', 'DESC'], ['createdAt', 'DESC']],
      limit: safeLimit,
      offset,
    });

    res.json({ transactions: rows, total: count, page: safePage, pages: Math.ceil(count / safeLimit) });
  } catch (err) {
    console.error('List transactions error:', err);
    res.status(500).json({ error: 'Failed to fetch transactions' });
  }
});

router.get('/trash', async (req, res) => {
  try {
    const rows = await Transaction.findAll({
      paranoid: false,
      where: {
        userId: req.userId,
        deletedAt: { [Op.ne]: null },
      },
      include: [
        { model: Category, attributes: ['id', 'name', 'nameHe', 'icon', 'color'] },
        { model: CreditCard, attributes: ['id', 'name', 'lastFourDigits', 'color'] },
      ],
      order: [['deletedAt', 'DESC']],
    });
    res.json({ transactions: rows });
  } catch (err) {
    console.error('Trash list error:', err);
    res.status(500).json({ error: 'Failed to fetch trash' });
  }
});

router.get('/bank-running-balances', async (req, res) => {
  try {
    const [rows] = await sequelize.query(
      `SELECT id,
        SUM(CASE WHEN type = 'income' THEN CAST(amount AS REAL) ELSE -CAST(amount AS REAL) END)
          OVER (ORDER BY date ASC, created_at ASC ROWS UNBOUNDED PRECEDING) AS balance_after
       FROM transactions
       WHERE user_id = :userId
         AND credit_card_id IS NULL
         AND COALESCE(is_billing_charge, 0) = 0
         AND deleted_at IS NULL`,
      { replacements: { userId: req.userId } },
    );

    const balances = {};
    for (const row of rows) {
      const v = row.balance_after;
      balances[row.id] = typeof v === 'number' ? v : parseFloat(String(v), 10);
    }
    res.json({ balances });
  } catch (err) {
    console.error('Bank running balances error:', err);
    res.status(500).json({ error: 'Failed to compute running balances' });
  }
});

router.get('/summary', async (req, res) => {
  try {
    try {
      const { processRecurringRules, processCreditCardBilling } = require('../services/recurringService');
      // Catch up recurring income/expense and card billing when the app opens the dashboard
      // (cron also runs daily; this covers cold starts / timezone edge cases).
      processRecurringRules().catch(() => {});
      processCreditCardBilling().catch(() => {});
    } catch (_) {}

    const { from, to } = req.query;
    const where = { userId: req.userId };
    if (from || to) {
      where.date = {};
      if (from) where.date[Op.gte] = from;
      if (to) where.date[Op.lte] = to;
    }

    const bankWhere = {
      ...where,
      creditCardId: null,
    };

    const categoryWhere = {
      ...where,
      isBillingCharge: false,
    };

    const income = await Transaction.sum('amount', { where: { ...bankWhere, type: 'income' } }) || 0;
    const expense = await Transaction.sum('amount', { where: { ...bankWhere, type: 'expense' } }) || 0;

    const byCategory = await Transaction.findAll({
      where: { ...categoryWhere, type: 'expense' },
      attributes: [
        'categoryId',
        [sequelize.fn('SUM', sequelize.col('amount')), 'total'],
        [sequelize.fn('COUNT', sequelize.col('Transaction.id')), 'count'],
      ],
      include: [{ model: Category, attributes: ['id', 'name', 'nameHe', 'icon', 'color'] }],
      group: ['categoryId', 'Category.id'],
      order: [[sequelize.fn('SUM', sequelize.col('amount')), 'DESC']],
    });

    res.json({
      income: parseFloat(income),
      expense: parseFloat(expense),
      balance: parseFloat(income) - parseFloat(expense),
      byCategory,
    });
  } catch (err) {
    console.error('Summary error:', err);
    res.status(500).json({ error: 'Failed to fetch summary' });
  }
});

router.post('/', async (req, res) => {
  try {
    let { amount, currency, type, note, date, categoryId, creditCardId, installments } = req.body;

    categoryId = await applyCategoryRules(req.userId, note, categoryId);

    const numericAmount = Number(amount);
    if (!Number.isFinite(numericAmount) || numericAmount <= 0) {
      return res.status(400).json({ error: 'Amount must be a positive number' });
    }
    if (type !== 'income' && type !== 'expense') {
      return res.status(400).json({ error: 'Type must be income or expense' });
    }

    if (!(await ensureCategoryOwnership(categoryId, req.userId))) {
      return res.status(403).json({ error: 'Invalid category' });
    }
    if (!(await ensureCreditCardOwnership(creditCardId, req.userId))) {
      return res.status(403).json({ error: 'Invalid credit card' });
    }

    async function shouldMarkBilled(cardId, txnDate) {
      if (!cardId || !txnDate) return false;
      const card = await CreditCard.findByPk(cardId);
      if (!card) return false;

      const now = new Date();
      const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
      const billingDay = card.billingDay;

      let cycleStart;
      if (today.getDate() >= billingDay) {
        cycleStart = new Date(today.getFullYear(), today.getMonth(), billingDay);
      } else {
        cycleStart = new Date(today.getFullYear(), today.getMonth() - 1, billingDay);
      }

      const [y, m, d] = txnDate.split('-').map(Number);
      const txnDateObj = new Date(y, m - 1, d);

      return txnDateObj < cycleStart;
    }

    const numInstallments = parseInt(installments) || 1;

    if (numInstallments > 1 && creditCardId) {
      const groupId = uuidv4();
      const perInstallment = Math.round((numericAmount / numInstallments) * 100) / 100;
      const remainder = Math.round((numericAmount - perInstallment * numInstallments) * 100) / 100;

      const dateStr = date || new Date().toISOString().split('T')[0];
      const [baseY, baseM, baseD] = dateStr.split('-').map(Number);

      const firstTransaction = await sequelize.transaction(async (t) => {
        let firstTxn = null;
        for (let i = 0; i < numInstallments; i++) {
          let newMonth = baseM + i;
          let newYear = baseY;
          while (newMonth > 12) { newMonth -= 12; newYear += 1; }
          const daysInMonth = new Date(newYear, newMonth, 0).getDate();
          const day = Math.min(baseD, daysInMonth);
          const installmentDateStr = `${newYear}-${String(newMonth).padStart(2, '0')}-${String(day).padStart(2, '0')}`;

          const installmentAmount = i === 0 ? perInstallment + remainder : perInstallment;
          const billed = await shouldMarkBilled(creditCardId, installmentDateStr);

          const txn = await Transaction.create({
            amount: installmentAmount,
            currency: currency || 'ILS',
            type,
            note: note || '',
            date: installmentDateStr,
            categoryId,
            creditCardId,
            userId: req.userId,
            installmentNumber: i + 1,
            installmentCount: numInstallments,
            installmentGroupId: groupId,
            isBilled: billed,
          }, { transaction: t });

          if (i === 0) firstTxn = txn;
        }
        return firstTxn;
      });

      const full = await Transaction.findByPk(firstTransaction.id, {
        include: [
          { model: Category, attributes: ['id', 'name', 'nameHe', 'icon', 'color'] },
          { model: CreditCard, attributes: ['id', 'name', 'lastFourDigits', 'color'] },
        ],
      });

      return res.status(201).json({ transaction: full });
    }

    const txnDate = date || new Date().toISOString().split('T')[0];
    const billed = await shouldMarkBilled(creditCardId, txnDate);

    const transaction = await Transaction.create({
      amount: numericAmount,
      currency: currency || 'ILS',
      type,
      note: note || '',
      date: txnDate,
      categoryId,
      creditCardId: creditCardId || null,
      userId: req.userId,
      isBilled: billed,
    });

    const full = await Transaction.findByPk(transaction.id, {
      include: [
        { model: Category, attributes: ['id', 'name', 'nameHe', 'icon', 'color'] },
        { model: CreditCard, attributes: ['id', 'name', 'lastFourDigits', 'color'] },
      ],
    });

    res.status(201).json({ transaction: full });
  } catch (err) {
    console.error('Create transaction error:', err);
    res.status(500).json({ error: 'Failed to create transaction' });
  }
});

router.put('/:id', async (req, res) => {
  try {
    const transaction = await Transaction.findOne({
      where: { id: req.params.id, userId: req.userId },
    });
    if (!transaction) return res.status(404).json({ error: 'Transaction not found' });

    const { amount, currency, type, note, date, categoryId, creditCardId } = req.body;

    if (categoryId !== undefined && !(await ensureCategoryOwnership(categoryId, req.userId))) {
      return res.status(403).json({ error: 'Invalid category' });
    }
    if (creditCardId !== undefined && !(await ensureCreditCardOwnership(creditCardId, req.userId))) {
      return res.status(403).json({ error: 'Invalid credit card' });
    }
    if (amount !== undefined) {
      const n = Number(amount);
      if (!Number.isFinite(n) || n <= 0) {
        return res.status(400).json({ error: 'Amount must be a positive number' });
      }
      transaction.amount = n;
    }
    if (currency !== undefined) transaction.currency = currency;
    if (type !== undefined) {
      if (type !== 'income' && type !== 'expense') {
        return res.status(400).json({ error: 'Type must be income or expense' });
      }
      transaction.type = type;
    }
    if (note !== undefined) transaction.note = note;
    if (date !== undefined) transaction.date = date;
    if (categoryId !== undefined) transaction.categoryId = categoryId;
    if (creditCardId !== undefined) transaction.creditCardId = creditCardId;
    await transaction.save();

    const full = await Transaction.findByPk(transaction.id, {
      include: [
        { model: Category, attributes: ['id', 'name', 'nameHe', 'icon', 'color'] },
        { model: CreditCard, attributes: ['id', 'name', 'lastFourDigits', 'color'] },
      ],
    });

    res.json({ transaction: full });
  } catch (err) {
    console.error('Update transaction error:', err);
    res.status(500).json({ error: 'Failed to update transaction' });
  }
});

router.post('/:id/restore', async (req, res) => {
  try {
    const transaction = await Transaction.findOne({
      where: { id: req.params.id, userId: req.userId },
      paranoid: false,
    });
    if (!transaction || !transaction.deletedAt) {
      return res.status(404).json({ error: 'Transaction not found in trash' });
    }
    await transaction.restore();
    const full = await Transaction.findByPk(transaction.id, {
      include: [
        { model: Category, attributes: ['id', 'name', 'nameHe', 'icon', 'color'] },
        { model: CreditCard, attributes: ['id', 'name', 'lastFourDigits', 'color'] },
      ],
    });
    res.json({ transaction: full });
  } catch (err) {
    console.error('Restore transaction error:', err);
    res.status(500).json({ error: 'Failed to restore transaction' });
  }
});

router.delete('/:id', async (req, res) => {
  try {
    const deleted = await Transaction.destroy({
      where: { id: req.params.id, userId: req.userId },
    });
    if (!deleted) return res.status(404).json({ error: 'Transaction not found' });
    res.json({ success: true });
  } catch (err) {
    console.error('Delete transaction error:', err);
    res.status(500).json({ error: 'Failed to delete transaction' });
  }
});

module.exports = router;
