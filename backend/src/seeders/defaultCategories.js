const defaultCategories = [
  { name: 'Food & Dining', nameHe: 'אוכל ומסעדות', icon: '🍔', color: '#FF9500', type: 'expense' },
  { name: 'Transportation', nameHe: 'תחבורה', icon: '🚗', color: '#5856D6', type: 'expense' },
  { name: 'Shopping', nameHe: 'קניות', icon: '🛍️', color: '#FF2D55', type: 'expense' },
  { name: 'Entertainment', nameHe: 'בילויים ופנאי', icon: '🎬', color: '#AF52DE', type: 'expense' },
  { name: 'Health', nameHe: 'בריאות', icon: '💊', color: '#FF3B30', type: 'expense' },
  { name: 'Education', nameHe: 'חינוך ולימודים', icon: '📚', color: '#007AFF', type: 'expense' },
  { name: 'Bills & Utilities', nameHe: 'חשבונות ושירותים', icon: '💡', color: '#FFCC00', type: 'expense' },
  { name: 'Housing', nameHe: 'דיור', icon: '🏠', color: '#34C759', type: 'expense' },
  { name: 'Personal Care', nameHe: 'טיפוח אישי', icon: '💇', color: '#FF6482', type: 'expense' },
  { name: 'Groceries', nameHe: 'סופרמרקט', icon: '🛒', color: '#4CD964', type: 'expense' },
  { name: 'Subscriptions', nameHe: 'מנויים', icon: '📱', color: '#5AC8FA', type: 'expense' },
  { name: 'Other Expense', nameHe: 'הוצאה אחרת', icon: '📦', color: '#8E8E93', type: 'expense' },
  { name: 'Salary', nameHe: 'משכורת', icon: '💼', color: '#34C759', type: 'income' },
  { name: 'Freelance', nameHe: 'פרילנס', icon: '💻', color: '#007AFF', type: 'income' },
  { name: 'Investment', nameHe: 'השקעות', icon: '📈', color: '#5856D6', type: 'income' },
  { name: 'Gift', nameHe: 'מתנה', icon: '🎁', color: '#FF2D55', type: 'income' },
  { name: 'Other Income', nameHe: 'הכנסה אחרת', icon: '💰', color: '#8E8E93', type: 'income' },
];

async function seedDefaultCategories(userId) {
  const { Category } = require('../models');
  const records = defaultCategories.map((cat) => ({
    ...cat,
    userId,
    isDefault: true,
  }));
  await Category.bulkCreate(records);
}

module.exports = { defaultCategories, seedDefaultCategories };
