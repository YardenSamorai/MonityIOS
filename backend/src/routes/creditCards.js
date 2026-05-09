const express = require('express');
const { Op } = require('sequelize');
const sequelize = require('../config/database');
const { CreditCard, Transaction, Category, User } = require('../models');
const { authMiddleware } = require('../middleware/auth');

const router = express.Router();
router.use(authMiddleware);

function toLocalDateStr(d) {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

router.get('/', async (req, res) => {
  try {
    const cards = await CreditCard.findAll({
      where: { userId: req.userId },
      order: [['sortOrder', 'ASC'], ['createdAt', 'DESC']],
    });

    const cardsWithBalance = await Promise.all(
      cards.map(async (card) => {
        const unbilled = await Transaction.sum('amount', {
          where: {
            creditCardId: card.id,
            isBilled: false,
            type: 'expense',
          },
        }) || 0;
        const unbilledCredits = await Transaction.sum('amount', {
          where: {
            creditCardId: card.id,
            isBilled: false,
            type: 'income',
          },
        }) || 0;
        return {
          ...card.toJSON(),
          currentBalance: parseFloat(unbilled) - parseFloat(unbilledCredits),
        };
      })
    );

    res.json({ creditCards: cardsWithBalance });
  } catch (err) {
    console.error('List credit cards error:', err);
    res.status(500).json({ error: 'Failed to fetch credit cards' });
  }
});

router.put('/reorder', async (req, res) => {
  try {
    const { orderedIds } = req.body;
    if (!Array.isArray(orderedIds)) {
      return res.status(400).json({ error: 'orderedIds array is required' });
    }

    await Promise.all(
      orderedIds.map((id, index) =>
        CreditCard.update({ sortOrder: index }, { where: { id, userId: req.userId } })
      )
    );

    res.json({ success: true });
  } catch (err) {
    console.error('Reorder credit cards error:', err);
    res.status(500).json({ error: 'Failed to reorder credit cards' });
  }
});

router.get('/:id', async (req, res) => {
  try {
    const card = await CreditCard.findOne({
      where: { id: req.params.id, userId: req.userId },
    });
    if (!card) return res.status(404).json({ error: 'Credit card not found' });

    const unbilled = await Transaction.sum('amount', {
      where: { creditCardId: card.id, isBilled: false, type: 'expense' },
    }) || 0;
    const unbilledCredits = await Transaction.sum('amount', {
      where: { creditCardId: card.id, isBilled: false, type: 'income' },
    }) || 0;

    const transactions = await Transaction.findAll({
      where: { creditCardId: card.id, isBilled: false },
      include: [{ model: Category, attributes: ['id', 'name', 'nameHe', 'icon', 'color'] }],
      order: [['date', 'DESC'], ['createdAt', 'DESC']],
    });

    res.json({
      creditCard: {
        ...card.toJSON(),
        currentBalance: parseFloat(unbilled) - parseFloat(unbilledCredits),
      },
      transactions,
    });
  } catch (err) {
    console.error('Get credit card error:', err);
    res.status(500).json({ error: 'Failed to fetch credit card' });
  }
});

router.get('/:id/history', async (req, res) => {
  try {
    const card = await CreditCard.findOne({
      where: { id: req.params.id, userId: req.userId },
    });
    if (!card) return res.status(404).json({ error: 'Credit card not found' });

    const now = new Date();
    const month = req.query.month || `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;

    const [year, mon] = month.split('-').map(Number);
    const from = `${year}-${String(mon).padStart(2, '0')}-01`;
    const lastDay = new Date(year, mon, 0).getDate();
    const to = `${year}-${String(mon).padStart(2, '0')}-${String(lastDay).padStart(2, '0')}`;

    const transactions = await Transaction.findAll({
      where: {
        creditCardId: card.id,
        date: { [Op.gte]: from, [Op.lte]: to },
      },
      include: [{ model: Category, attributes: ['id', 'name', 'nameHe', 'icon', 'color'] }],
      order: [['date', 'DESC'], ['createdAt', 'DESC']],
    });

    const totalExpenses = transactions
      .filter(t => t.type === 'expense')
      .reduce((sum, t) => sum + parseFloat(t.amount), 0);
    const totalCredits = transactions
      .filter(t => t.type === 'income')
      .reduce((sum, t) => sum + parseFloat(t.amount), 0);

    const allDates = await Transaction.findAll({
      attributes: [[sequelize.fn('DISTINCT', sequelize.fn('SUBSTR', sequelize.col('date'), 1, 7)), 'month']],
      where: { creditCardId: card.id },
      raw: true,
    });
    const availableMonths = allDates
      .map(r => r.month)
      .filter(Boolean)
      .sort();

    res.json({
      month,
      transactions,
      summary: {
        totalExpenses,
        totalCredits,
        netCharge: totalExpenses - totalCredits,
      },
      availableMonths,
    });
  } catch (err) {
    console.error('Credit card history error:', err);
    res.status(500).json({ error: 'Failed to fetch credit card history' });
  }
});

router.post('/', async (req, res) => {
  try {
    const { name, lastFourDigits, billingDay, creditLimit, color } = req.body;

    if (!name || !billingDay) {
      return res.status(400).json({ error: 'name and billingDay are required' });
    }
    if (billingDay < 1 || billingDay > 28) {
      return res.status(400).json({ error: 'billingDay must be between 1 and 28' });
    }

    const card = await CreditCard.create({
      name,
      lastFourDigits: lastFourDigits || '',
      billingDay,
      creditLimit: creditLimit || null,
      color: color || '#6C63FF',
      userId: req.userId,
    });

    res.status(201).json({ creditCard: { ...card.toJSON(), currentBalance: 0 } });
  } catch (err) {
    console.error('Create credit card error:', err);
    res.status(500).json({ error: 'Failed to create credit card' });
  }
});

router.put('/:id', async (req, res) => {
  try {
    const card = await CreditCard.findOne({
      where: { id: req.params.id, userId: req.userId },
    });
    if (!card) return res.status(404).json({ error: 'Credit card not found' });

    if (req.body.billingDay !== undefined) {
      const day = parseInt(req.body.billingDay, 10);
      if (!Number.isFinite(day) || day < 1 || day > 28) {
        return res.status(400).json({ error: 'billingDay must be between 1 and 28' });
      }
    }

    const fields = ['name', 'lastFourDigits', 'billingDay', 'creditLimit', 'color', 'isActive'];
    fields.forEach((f) => {
      if (req.body[f] !== undefined) card[f] = req.body[f];
    });
    await card.save();

    res.json({ creditCard: card });
  } catch (err) {
    console.error('Update credit card error:', err);
    res.status(500).json({ error: 'Failed to update credit card' });
  }
});

router.delete('/:id', async (req, res) => {
  try {
    const deleted = await CreditCard.destroy({
      where: { id: req.params.id, userId: req.userId },
    });
    if (!deleted) return res.status(404).json({ error: 'Credit card not found' });
    res.json({ success: true });
  } catch (err) {
    console.error('Delete credit card error:', err);
    res.status(500).json({ error: 'Failed to delete credit card' });
  }
});

router.post('/:id/bill', async (req, res) => {
  try {
    const card = await CreditCard.findOne({
      where: { id: req.params.id, userId: req.userId },
    });
    if (!card) return res.status(404).json({ error: 'Credit card not found' });

    const unbilledTxns = await Transaction.findAll({
      where: { creditCardId: card.id, isBilled: false },
      attributes: ['type', 'amount', 'currency'],
    });

    if (unbilledTxns.length === 0) {
      return res.json({ message: 'No charges to bill', charged: 0 });
    }

    const currencyTotals = {};
    for (const t of unbilledTxns) {
      const cur = t.currency || 'ILS';
      const amt = parseFloat(t.amount);
      if (!currencyTotals[cur]) currencyTotals[cur] = 0;
      currencyTotals[cur] += t.type === 'expense' ? amt : -amt;
    }

    const user = await User.findByPk(req.userId, { attributes: ['preferredCurrency'] });
    let billingCurrency = user?.preferredCurrency || 'ILS';
    const currenciesUsed = Object.keys(currencyTotals);
    if (currenciesUsed.length === 1) {
      billingCurrency = currenciesUsed[0];
    }

    const totalCharge = currencyTotals[billingCurrency] || 0;
    if (totalCharge <= 0 && currenciesUsed.length === 1) {
      return res.json({ message: 'No charges to bill', charged: 0 });
    }

    const todayStr = toLocalDateStr(new Date());

    const chargeTransaction = await sequelize.transaction(async (t) => {
      await Transaction.update(
        { isBilled: true },
        { where: { creditCardId: card.id, isBilled: false }, transaction: t }
      );

      const txn = await Transaction.create({
        amount: Math.abs(totalCharge),
        currency: billingCurrency,
        type: totalCharge >= 0 ? 'expense' : 'income',
        note: `חיוב כרטיס ${card.name} ${card.lastFourDigits ? `(${card.lastFourDigits})` : ''}`.trim(),
        date: todayStr,
        userId: req.userId,
        creditCardId: null,
        isBilled: true,
        isBillingCharge: true,
      }, { transaction: t });

      card.lastBilledAt = todayStr;
      await card.save({ transaction: t });

      return txn;
    });

    res.json({
      charged: totalCharge,
      transaction: chargeTransaction,
      currencyBreakdown: currenciesUsed.length > 1 ? currencyTotals : undefined,
    });
  } catch (err) {
    console.error('Bill credit card error:', err);
    res.status(500).json({ error: 'Failed to bill credit card' });
  }
});

module.exports = router;
