const { CategoryRule } = require('../models');

async function applyCategoryRules(userId, note, categoryId) {
  if (categoryId !== undefined && categoryId !== null && categoryId !== '') {
    return categoryId;
  }
  const text = String(note || '').trim();
  if (!text) return categoryId;

  const rules = await CategoryRule.findAll({
    where: { userId },
    order: [['priority', 'DESC'], ['createdAt', 'ASC']],
  });

  const low = text.toLowerCase();
  for (const r of rules) {
    const p = String(r.pattern || '').toLowerCase();
    if (p && low.includes(p)) return r.categoryId;
  }
  return categoryId;
}

module.exports = { applyCategoryRules };
