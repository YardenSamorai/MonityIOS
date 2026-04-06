const express = require('express');
const { Op } = require('sequelize');
const { Transaction, Category } = require('../models');
const { authMiddleware } = require('../middleware/auth');

const router = express.Router();
router.use(authMiddleware);

router.get('/csv', async (req, res) => {
  try {
    const { from, to } = req.query;
    const where = { userId: req.userId };
    if (from || to) {
      where.date = {};
      if (from) where.date[Op.gte] = from;
      if (to) where.date[Op.lte] = to;
    }

    const transactions = await Transaction.findAll({
      where,
      include: [{ model: Category, attributes: ['name'] }],
      order: [['date', 'DESC']],
    });

    const header = 'Date,Type,Category,Amount,Currency,Note\n';
    const rows = transactions.map((t) => {
      const cat = t.Category ? t.Category.name : 'Uncategorized';
      const note = (t.note || '').replace(/"/g, '""');
      return `${t.date},${t.type},"${cat}",${t.amount},${t.currency},"${note}"`;
    });

    const csv = header + rows.join('\n');

    res.setHeader('Content-Type', 'text/csv');
    res.setHeader('Content-Disposition', 'attachment; filename=monity-export.csv');
    res.send(csv);
  } catch (err) {
    console.error('Export error:', err);
    res.status(500).json({ error: 'Failed to export data' });
  }
});

module.exports = router;
