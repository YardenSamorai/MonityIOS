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

    const numInstallments = parseInt(installments) || 1;

    if (numInstallments > 1 && creditCardId) {
      const groupId = uuidv4();
      const perInstallment = Math.round((amount / numInstallments) * 100) / 100;
      const remainder = Math.round((amount - perInstallment * numInstallments) * 100) / 100;

      const baseDate = date ? new Date(date) : new Date();
      let firstTransaction = null;

      for (let i = 0; i < numInstallments; i++) {
        const installmentDate = new Date(baseDate.getFullYear(), baseDate.getMonth() + i, baseDate.getDate());
        const y = installmentDate.getFullYear();
        const m = String(installmentDate.getMonth() + 1).padStart(2, '0');
        const d = String(installmentDate.getDate()).padStart(2, '0');
        const dateStr = `${y}-${m}-${d}`;

        const installmentAmount = i === 0 ? perInstallment + remainder : perInstallment;

        const txn = await Transaction.create({
          amount: installmentAmount,
          currency: currency || 'ILS',
          type,
          note: note || '',
          date: dateStr,
          categoryId,
          creditCardId,
          userId: req.userId,
          installmentNumber: i + 1,
          installmentCount: numInstallments,
          installmentGroupId: groupId,
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

    const transaction = await Transaction.create({
      amount,
      currency: currency || 'ILS',
      type,
      note: note || '',
      date: date || new Date(),
      categoryId,
      creditCardId: creditCardId || null,
      userId: req.userId,
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
