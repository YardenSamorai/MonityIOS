const express = require('express');
const { Op } = require('sequelize');
const sequelize = require('../config/database');
const { CreditCard, Transaction, Category } = require('../models');
const { authMiddleware } = require('../middleware/auth');

const router = express.Router();
router.use(authMiddleware);

router.get('/', async (req, res) => {
  try {
    const cards = await CreditCard.findAll({
      where: { userId: req.userId },
      order: [['createdAt', 'DESC']],
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

    const unbilledExpenses = await Transaction.sum('amount', {
      where: { creditCardId: card.id, isBilled: false, type: 'expense' },
    }) || 0;
    const unbilledCredits = await Transaction.sum('amount', {
      where: { creditCardId: card.id, isBilled: false, type: 'income' },
    }) || 0;
    const totalCharge = parseFloat(unbilledExpenses) - parseFloat(unbilledCredits);

    if (totalCharge <= 0) {
      return res.json({ message: 'No charges to bill', charged: 0 });
    }

    await Transaction.update(
      { isBilled: true },
      { where: { creditCardId: card.id, isBilled: false } }
    );

    const todayStr = new Date().toISOString().split('T')[0];
    const chargeTransaction = await Transaction.create({
      amount: totalCharge,
      currency: 'ILS',
      type: 'expense',
      note: `חיוב כרטיס ${card.name} ${card.lastFourDigits ? `(${card.lastFourDigits})` : ''}`.trim(),
      date: todayStr,
      userId: req.userId,
      creditCardId: null,
      isBilled: true,
    });

    card.lastBilledAt = todayStr;
    await card.save();

    res.json({
      charged: totalCharge,
      transaction: chargeTransaction,
    });
  } catch (err) {
    console.error('Bill credit card error:', err);
    res.status(500).json({ error: 'Failed to bill credit card' });
  }
});

module.exports = router;
