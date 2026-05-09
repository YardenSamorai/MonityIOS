const express = require('express');
const { CategoryRule, Category } = require('../models');
const { authMiddleware } = require('../middleware/auth');

const router = express.Router();
router.use(authMiddleware);

router.get('/', async (req, res) => {
  try {
    const rules = await CategoryRule.findAll({
      where: { userId: req.userId },
      include: [{ model: Category, attributes: ['id', 'name', 'nameHe', 'icon', 'color'] }],
      order: [['priority', 'DESC'], ['createdAt', 'ASC']],
    });
    res.json({ rules });
  } catch (err) {
    console.error('Category rules list error:', err);
    res.status(500).json({ error: 'Failed to list rules' });
  }
});

router.post('/', async (req, res) => {
  try {
    const { pattern, categoryId, priority } = req.body;
    if (!pattern || categoryId === undefined || categoryId === null) {
      return res.status(400).json({ error: 'pattern and categoryId are required' });
    }
    const cat = await Category.findOne({
      where: { id: categoryId, userId: req.userId },
    });
    if (!cat) return res.status(403).json({ error: 'Invalid category' });

    const rule = await CategoryRule.create({
      userId: req.userId,
      pattern: String(pattern).slice(0, 200),
      categoryId: parseInt(categoryId, 10),
      priority: priority != null ? parseInt(priority, 10) : 0,
    });
    const full = await CategoryRule.findByPk(rule.id, {
      include: [{ model: Category, attributes: ['id', 'name', 'nameHe', 'icon', 'color'] }],
    });
    res.status(201).json({ rule: full });
  } catch (err) {
    console.error('Category rule create error:', err);
    res.status(500).json({ error: 'Failed to create rule' });
  }
});

router.put('/:id', async (req, res) => {
  try {
    const rule = await CategoryRule.findOne({
      where: { id: req.params.id, userId: req.userId },
    });
    if (!rule) return res.status(404).json({ error: 'Rule not found' });

    const { pattern, categoryId, priority } = req.body;
    if (pattern !== undefined) rule.pattern = String(pattern).slice(0, 200);
    if (categoryId !== undefined) {
      const cat = await Category.findOne({
        where: { id: categoryId, userId: req.userId },
      });
      if (!cat) return res.status(403).json({ error: 'Invalid category' });
      rule.categoryId = parseInt(categoryId, 10);
    }
    if (priority !== undefined) rule.priority = parseInt(priority, 10);
    await rule.save();
    const full = await CategoryRule.findByPk(rule.id, {
      include: [{ model: Category, attributes: ['id', 'name', 'nameHe', 'icon', 'color'] }],
    });
    res.json({ rule: full });
  } catch (err) {
    console.error('Category rule update error:', err);
    res.status(500).json({ error: 'Failed to update rule' });
  }
});

router.delete('/:id', async (req, res) => {
  try {
    const n = await CategoryRule.destroy({
      where: { id: req.params.id, userId: req.userId },
    });
    if (!n) return res.status(404).json({ error: 'Rule not found' });
    res.json({ success: true });
  } catch (err) {
    console.error('Category rule delete error:', err);
    res.status(500).json({ error: 'Failed to delete rule' });
  }
});

module.exports = router;
