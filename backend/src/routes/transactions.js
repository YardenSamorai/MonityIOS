const express = require('express');
const { Op } = require('sequelize');
const { v4: uuidv4 } = require('uuid');
const sequelize = require('../config/database');
const { Transaction, Category, CreditCard } = require('../models');
const { authMiddleware } = require('../middleware/auth');

const router = express.Router();
router.use(authMiddleware);

router.get('/', async (req, res) => {
  try {
    const { type, categoryId, from, to, page = 1, limit = 50 } = req.query;
    const where = { userId: req.userId };

    if (type) where.type = type;
    if (categoryId) where.categoryId = categoryId;
    if (req.query.creditCardId) where.creditCardId = req.query.creditCardId;
    if (from || to) {
      where.date = {};
      if (from) where.date[Op.gte] = from;
      if (to) where.date[Op.lte] = to;
    }

    const offset = (parseInt(page) - 1) * parseInt(limit);
    const { rows, count } = await Transaction.findAndCountAll({
      where,
      include: [
        { model: Category, attributes: ['id', 'name', 'nameHe', 'icon', 'color'] },
        { model: CreditCard, attributes: ['id', 'name', 'lastFourDigits', 'color'] },
      ],
      order: [['date', 'DESC'], ['createdAt', 'DESC']],
      limit: parseInt(limit),
      offset,
    });

    res.json({ transactions: rows, total: count, page: parseInt(page), pages: Math.ceil(count / parseInt(limit)) });
  } catch (err) {
    console.error('List transactions error:', err);
    res.status(500).json({ error: 'Failed to fetch transactions' });
  }
});

router.get('/summary', async (req, res) => {
  try {
    const { from, to } = req.query;
    const where = { userId: req.userId };
    if (from || to) {
      where.date = {};
      if (from) where.date[Op.gte] = from;
      if (to) where.date[Op.lte] = to;
    }

    const bankWhere = {
      ...where,
      [Op.or]: [
        { creditCardId: null },
        { isBilled: true },
      ],
    };

    const income = await Transaction.sum('amount', { where: { ...bankWhere, type: 'income' } }) || 0;
    const expense = await Transaction.sum('amount', { where: { ...bankWhere, type: 'expense' } }) || 0;

    const byCategory = await Transaction.findAll({
      where: { ...where, type: 'expense' },
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
    const { amount, currency, type, note, date, categoryId, creditCardId, installments } = req.body;

    if (!amount || !type) {
      return res.status(400).json({ error: 'Amount and type are required' });
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
      const perInstallment = Math.round((amount / numInstallments) * 100) / 100;
      const remainder = Math.round((amount - perInstallment * numInstallments) * 100) / 100;

      const dateStr = date || new Date().toISOString().split('T')[0];
      const [baseY, baseM, baseD] = dateStr.split('-').map(Number);
      let firstTransaction = null;

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
        });

        if (i === 0) firstTransaction = txn;
      }

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
      amount,
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
    if (amount !== undefined) transaction.amount = amount;
    if (currency !== undefined) transaction.currency = currency;
    if (type !== undefined) transaction.type = type;
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
