const express = require('express');
const { SavingsGoal } = require('../models');
const { authMiddleware } = require('../middleware/auth');

const router = express.Router();
router.use(authMiddleware);

router.get('/', async (req, res) => {
  try {
    const goals = await SavingsGoal.findAll({
      where: { userId: req.userId },
      order: [['sortOrder', 'ASC'], ['createdAt', 'ASC']],
    });
    res.json({ goals });
  } catch (err) {
    console.error('Goals list error:', err);
    res.status(500).json({ error: 'Failed to list goals' });
  }
});

router.post('/', async (req, res) => {
  try {
    const { name, targetAmount, currentAmount, currency, targetDate, sortOrder } = req.body;
    if (!name || targetAmount === undefined) {
      return res.status(400).json({ error: 'name and targetAmount are required' });
    }
    const goal = await SavingsGoal.create({
      userId: req.userId,
      name: String(name).slice(0, 120),
      targetAmount: Number(targetAmount),
      currentAmount: currentAmount != null ? Number(currentAmount) : 0,
      currency: (currency || 'ILS').slice(0, 3),
      targetDate: targetDate || null,
      sortOrder: sortOrder != null ? parseInt(sortOrder, 10) : 0,
    });
    res.status(201).json({ goal });
  } catch (err) {
    console.error('Goal create error:', err);
    res.status(500).json({ error: 'Failed to create goal' });
  }
});

router.put('/:id', async (req, res) => {
  try {
    const goal = await SavingsGoal.findOne({
      where: { id: req.params.id, userId: req.userId },
    });
    if (!goal) return res.status(404).json({ error: 'Goal not found' });

    const { name, targetAmount, currentAmount, currency, targetDate, sortOrder } = req.body;
    if (name !== undefined) goal.name = String(name).slice(0, 120);
    if (targetAmount !== undefined) goal.targetAmount = Number(targetAmount);
    if (currentAmount !== undefined) goal.currentAmount = Number(currentAmount);
    if (currency !== undefined) goal.currency = String(currency).slice(0, 3);
    if (targetDate !== undefined) goal.targetDate = targetDate || null;
    if (sortOrder !== undefined) goal.sortOrder = parseInt(sortOrder, 10);
    await goal.save();
    res.json({ goal });
  } catch (err) {
    console.error('Goal update error:', err);
    res.status(500).json({ error: 'Failed to update goal' });
  }
});

router.delete('/:id', async (req, res) => {
  try {
    const n = await SavingsGoal.destroy({
      where: { id: req.params.id, userId: req.userId },
    });
    if (!n) return res.status(404).json({ error: 'Goal not found' });
    res.json({ success: true });
  } catch (err) {
    console.error('Goal delete error:', err);
    res.status(500).json({ error: 'Failed to delete goal' });
  }
});

module.exports = router;
