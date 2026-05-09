const express = require('express');
const { RecurringRule, Category, Transaction } = require('../models');
const { authMiddleware } = require('../middleware/auth');
const { processRecurringRules } = require('../services/recurringService');

const router = express.Router();
router.use(authMiddleware);

router.get('/', async (req, res) => {
  try {
    try {
      await processRecurringRules();
    } catch (err) {
      console.warn('processRecurringRules during /recurring GET failed:', err.message);
    }

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

    const numericAmount = Number(amount);
    if (!Number.isFinite(numericAmount) || numericAmount <= 0) {
      return res.status(400).json({ error: 'Amount must be a positive number' });
    }
    if (!type || !frequency || !startDate) {
      return res.status(400).json({ error: 'type, frequency, and startDate are required' });
    }

    if (categoryId !== undefined && categoryId !== null) {
      const cat = await Category.findOne({ where: { id: categoryId, userId: req.userId } });
      if (!cat) return res.status(403).json({ error: 'Invalid category' });
    }

    const rule = await RecurringRule.create({
      amount: numericAmount,
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

    processRecurringRules().catch(err => console.error('Post-create recurring processing error:', err));
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

    if (req.body.categoryId !== undefined && req.body.categoryId !== null) {
      const cat = await Category.findOne({ where: { id: req.body.categoryId, userId: req.userId } });
      if (!cat) return res.status(403).json({ error: 'Invalid category' });
    }
    if (req.body.amount !== undefined) {
      const n = Number(req.body.amount);
      if (!Number.isFinite(n) || n <= 0) {
        return res.status(400).json({ error: 'Amount must be a positive number' });
      }
    }

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

router.post('/:id/run-now', async (req, res) => {
  try {
    const rule = await RecurringRule.findOne({
      where: { id: req.params.id, userId: req.userId },
    });
    if (!rule) return res.status(404).json({ error: 'Recurring rule not found' });

    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const y = today.getFullYear();
    const m = String(today.getMonth() + 1).padStart(2, '0');
    const d = String(today.getDate()).padStart(2, '0');
    const todayStr = `${y}-${m}-${d}`;

    const { Transaction } = require('../models');
    const sequelize = require('../config/database');

    let monthFrom, monthTo;
    if (rule.frequency === 'monthly') {
      monthFrom = `${y}-${m}-01`;
      const lastDay = new Date(y, today.getMonth() + 1, 0).getDate();
      monthTo = `${y}-${m}-${String(lastDay).padStart(2, '0')}`;
    } else {
      monthFrom = todayStr;
      monthTo = todayStr;
    }

    const existing = await Transaction.findOne({
      where: {
        recurringRuleId: rule.id,
        date: { [require('sequelize').Op.between]: [monthFrom, monthTo] },
      },
    });

    if (existing) {
      return res.status(409).json({ error: 'Transaction already exists for this period' });
    }

    let occurrenceDate = todayStr;
    if (rule.frequency === 'monthly') {
      const startParts = rule.startDate.split('-').map(Number);
      const lastDay = new Date(y, today.getMonth() + 1, 0).getDate();
      const day = Math.min(startParts[2], lastDay);
      occurrenceDate = `${y}-${m}-${String(day).padStart(2, '0')}`;
    }

    await sequelize.transaction(async (t) => {
      await Transaction.create({
        amount: rule.amount,
        currency: rule.currency,
        type: rule.type,
        note: rule.note,
        date: occurrenceDate,
        categoryId: rule.categoryId,
        userId: rule.userId,
        recurringRuleId: rule.id,
      }, { transaction: t });

      if (!rule.lastGenerated || rule.lastGenerated < occurrenceDate) {
        rule.lastGenerated = occurrenceDate;
        await rule.save({ transaction: t });
      }
    });

    res.json({ success: true, generatedDate: occurrenceDate });
  } catch (err) {
    console.error('Run recurring rule error:', err);
    res.status(500).json({ error: 'Failed to run recurring rule' });
  }
});

router.delete('/:id', async (req, res) => {
  try {
    const rule = await RecurringRule.findOne({
      where: { id: req.params.id, userId: req.userId },
    });
    if (!rule) return res.status(404).json({ error: 'Recurring rule not found' });

    await Transaction.update(
      { recurringRuleId: null },
      { where: { recurringRuleId: rule.id } }
    );

    await rule.destroy();
    res.json({ success: true });
  } catch (err) {
    console.error('Delete recurring error:', err);
    res.status(500).json({ error: 'Failed to delete recurring rule' });
  }
});

module.exports = router;
