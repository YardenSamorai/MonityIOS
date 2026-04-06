const express = require('express');
const { Op } = require('sequelize');
const sequelize = require('../config/database');
const { Budget, Category, Transaction } = require('../models');
const { authMiddleware } = require('../middleware/auth');

const router = express.Router();
router.use(authMiddleware);

function getPeriodRange(period) {
  const now = new Date();
  let from, to;
  if (period === 'weekly') {
    const day = now.getDay();
    from = new Date(now);
    from.setDate(now.getDate() - day);
    to = new Date(from);
    to.setDate(from.getDate() + 6);
  } else if (period === 'yearly') {
    from = new Date(now.getFullYear(), 0, 1);
    to = new Date(now.getFullYear(), 11, 31);
  } else {
    from = new Date(now.getFullYear(), now.getMonth(), 1);
    to = new Date(now.getFullYear(), now.getMonth() + 1, 0);
  }
  return {
    from: from.toISOString().split('T')[0],
    to: to.toISOString().split('T')[0],
  };
}

router.get('/', async (req, res) => {
  try {
    const budgets = await Budget.findAll({
      where: { userId: req.userId },
      include: [{ model: Category, attributes: ['id', 'name', 'nameHe', 'icon', 'color'] }],
      order: [['createdAt', 'DESC']],
    });
    res.json({ budgets });
  } catch (err) {
    console.error('List budgets error:', err);
    res.status(500).json({ error: 'Failed to fetch budgets' });
  }
});

router.get('/status', async (req, res) => {
  try {
    const budgets = await Budget.findAll({
      where: { userId: req.userId },
      include: [{ model: Category, attributes: ['id', 'name', 'nameHe', 'icon', 'color'] }],
    });

    const statuses = await Promise.all(
      budgets.map(async (budget) => {
        const { from, to } = getPeriodRange(budget.period);
        const spent = await Transaction.sum('amount', {
          where: {
            userId: req.userId,
            categoryId: budget.categoryId,
            type: 'expense',
            date: { [Op.between]: [from, to] },
          },
        }) || 0;

        const limit = parseFloat(budget.limitAmount);
        const percentage = limit > 0 ? (parseFloat(spent) / limit) * 100 : 0;

        return {
          id: budget.id,
          category: budget.Category,
          limitAmount: limit,
          spent: parseFloat(spent),
          remaining: limit - parseFloat(spent),
          percentage: Math.round(percentage * 100) / 100,
          period: budget.period,
          status: percentage >= 100 ? 'exceeded' : percentage >= 80 ? 'warning' : 'ok',
        };
      })
    );

    res.json({ budgets: statuses });
  } catch (err) {
    console.error('Budget status error:', err);
    res.status(500).json({ error: 'Failed to fetch budget status' });
  }
});

router.post('/', async (req, res) => {
  try {
    const { limitAmount, period, categoryId } = req.body;
    if (!limitAmount || !categoryId) {
      return res.status(400).json({ error: 'limitAmount and categoryId are required' });
    }

    const existing = await Budget.findOne({
      where: { userId: req.userId, categoryId },
    });
    if (existing) {
      return res.status(409).json({ error: 'Budget already exists for this category' });
    }

    const budget = await Budget.create({
      limitAmount,
      period: period || 'monthly',
      categoryId,
      userId: req.userId,
    });

    const full = await Budget.findByPk(budget.id, {
      include: [{ model: Category, attributes: ['id', 'name', 'nameHe', 'icon', 'color'] }],
    });

    res.status(201).json({ budget: full });
  } catch (err) {
    console.error('Create budget error:', err);
    res.status(500).json({ error: 'Failed to create budget' });
  }
});

router.put('/:id', async (req, res) => {
  try {
    const budget = await Budget.findOne({
      where: { id: req.params.id, userId: req.userId },
    });
    if (!budget) return res.status(404).json({ error: 'Budget not found' });

    const { limitAmount, period } = req.body;
    if (limitAmount !== undefined) budget.limitAmount = limitAmount;
    if (period !== undefined) budget.period = period;
    await budget.save();

    const full = await Budget.findByPk(budget.id, {
      include: [{ model: Category, attributes: ['id', 'name', 'nameHe', 'icon', 'color'] }],
    });

    res.json({ budget: full });
  } catch (err) {
    console.error('Update budget error:', err);
    res.status(500).json({ error: 'Failed to update budget' });
  }
});

router.delete('/:id', async (req, res) => {
  try {
    const deleted = await Budget.destroy({
      where: { id: req.params.id, userId: req.userId },
    });
    if (!deleted) return res.status(404).json({ error: 'Budget not found' });
    res.json({ success: true });
  } catch (err) {
    console.error('Delete budget error:', err);
    res.status(500).json({ error: 'Failed to delete budget' });
  }
});

module.exports = router;
