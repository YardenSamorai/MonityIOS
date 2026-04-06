const express = require('express');
const { Category } = require('../models');
const { authMiddleware } = require('../middleware/auth');

const router = express.Router();
router.use(authMiddleware);

router.get('/', async (req, res) => {
  try {
    const { type } = req.query;
    const where = { userId: req.userId };
    if (type) where.type = type === 'both' ? type : { [require('sequelize').Op.in]: [type, 'both'] };

    const categories = await Category.findAll({ where, order: [['id', 'ASC']] });
    res.json({ categories });
  } catch (err) {
    console.error('List categories error:', err);
    res.status(500).json({ error: 'Failed to fetch categories' });
  }
});

router.post('/', async (req, res) => {
  try {
    const { name, icon, color, type } = req.body;
    if (!name) return res.status(400).json({ error: 'Name is required' });

    const category = await Category.create({
      name,
      icon: icon || '💰',
      color: color || '#007AFF',
      type: type || 'expense',
      userId: req.userId,
      isDefault: false,
    });

    res.status(201).json({ category });
  } catch (err) {
    console.error('Create category error:', err);
    res.status(500).json({ error: 'Failed to create category' });
  }
});

router.put('/:id', async (req, res) => {
  try {
    const category = await Category.findOne({
      where: { id: req.params.id, userId: req.userId },
    });
    if (!category) return res.status(404).json({ error: 'Category not found' });

    const { name, icon, color, type } = req.body;
    if (name !== undefined) category.name = name;
    if (icon !== undefined) category.icon = icon;
    if (color !== undefined) category.color = color;
    if (type !== undefined) category.type = type;
    await category.save();

    res.json({ category });
  } catch (err) {
    console.error('Update category error:', err);
    res.status(500).json({ error: 'Failed to update category' });
  }
});

router.delete('/:id', async (req, res) => {
  try {
    const category = await Category.findOne({
      where: { id: req.params.id, userId: req.userId },
    });
    if (!category) return res.status(404).json({ error: 'Category not found' });
    if (category.isDefault) return res.status(400).json({ error: 'Cannot delete default category' });

    await category.destroy();
    res.json({ success: true });
  } catch (err) {
    console.error('Delete category error:', err);
    res.status(500).json({ error: 'Failed to delete category' });
  }
});

module.exports = router;
