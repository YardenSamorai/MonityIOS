const express = require('express');
const { RecurringRule, Category } = require('../models');
const { authMiddleware } = require('../middleware/auth');

const router = express.Router();
router.use(authMiddleware);

router.get('/', async (req, res) => {
  try {
    const rules = await RecurringRule.findAll({
      where: { userId: req.userId },
      include: [{ model: Category, attributes: ['id', 'name', 'nameHe', 'icon', 'color'] }],
      order: [['createdAt', 'DESC']],
    });
    res.json({ recurringRules: rules });
  } catch (err) {
    console.error('List recurring error:', err);
    res.status(500).json({ error: 'Failed to fetch recurring rules' });
  }
});

router.post('/', async (req, res) => {
  try {
    const { amount, currency, type, frequency, startDate, endDate, categoryId, note } = req.body;

    if (!amount || !type || !frequency || !startDate) {
      return res.status(400).json({ error: 'amount, type, frequency, and startDate are required' });
    }

    const rule = await RecurringRule.create({
      amount,
      currency: currency || 'ILS',
      type,
      frequency,
      startDate,
      endDate: endDate || null,
      categoryId,
      userId: req.userId,
      note: note || '',
    });

    const full = await RecurringRule.findByPk(rule.id, {
      include: [{ model: Category, attributes: ['id', 'name', 'nameHe', 'icon', 'color'] }],
    });

    res.status(201).json({ recurringRule: full });
  } catch (err) {
    console.error('Create recurring error:', err);
    res.status(500).json({ error: 'Failed to create recurring rule' });
  }
});

router.put('/:id', async (req, res) => {
  try {
    const rule = await RecurringRule.findOne({
      where: { id: req.params.id, userId: req.userId },
    });
    if (!rule) return res.status(404).json({ error: 'Recurring rule not found' });

    const fields = ['amount', 'currency', 'type', 'frequency', 'startDate', 'endDate', 'categoryId', 'note', 'isActive'];
    fields.forEach((f) => {
      if (req.body[f] !== undefined) rule[f] = req.body[f];
    });
    await rule.save();

    const full = await RecurringRule.findByPk(rule.id, {
      include: [{ model: Category, attributes: ['id', 'name', 'nameHe', 'icon', 'color'] }],
    });

    res.json({ recurringRule: full });
  } catch (err) {
    console.error('Update recurring error:', err);
    res.status(500).json({ error: 'Failed to update recurring rule' });
  }
});

router.delete('/:id', async (req, res) => {
  try {
    const deleted = await RecurringRule.destroy({
      where: { id: req.params.id, userId: req.userId },
    });
    if (!deleted) return res.status(404).json({ error: 'Recurring rule not found' });
    res.json({ success: true });
  } catch (err) {
    console.error('Delete recurring error:', err);
    res.status(500).json({ error: 'Failed to delete recurring rule' });
  }
});

module.exports = router;
