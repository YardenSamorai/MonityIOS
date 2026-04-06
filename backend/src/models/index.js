const User = require('./User');
const Category = require('./Category');
const Transaction = require('./Transaction');
const Budget = require('./Budget');
const RecurringRule = require('./RecurringRule');
const CreditCard = require('./CreditCard');

User.hasMany(Category, { foreignKey: 'userId', onDelete: 'CASCADE' });
Category.belongsTo(User, { foreignKey: 'userId' });

User.hasMany(Transaction, { foreignKey: 'userId', onDelete: 'CASCADE' });
Transaction.belongsTo(User, { foreignKey: 'userId' });

Category.hasMany(Transaction, { foreignKey: 'categoryId', onDelete: 'SET NULL' });
Transaction.belongsTo(Category, { foreignKey: 'categoryId' });

User.hasMany(Budget, { foreignKey: 'userId', onDelete: 'CASCADE' });
Budget.belongsTo(User, { foreignKey: 'userId' });

Category.hasMany(Budget, { foreignKey: 'categoryId', onDelete: 'CASCADE' });
Budget.belongsTo(Category, { foreignKey: 'categoryId' });

User.hasMany(RecurringRule, { foreignKey: 'userId', onDelete: 'CASCADE' });
RecurringRule.belongsTo(User, { foreignKey: 'userId' });

Category.hasMany(RecurringRule, { foreignKey: 'categoryId', onDelete: 'SET NULL' });
RecurringRule.belongsTo(Category, { foreignKey: 'categoryId' });

RecurringRule.hasMany(Transaction, { foreignKey: 'recurringRuleId', onDelete: 'SET NULL' });
Transaction.belongsTo(RecurringRule, { foreignKey: 'recurringRuleId' });

User.hasMany(CreditCard, { foreignKey: 'userId', onDelete: 'CASCADE' });
CreditCard.belongsTo(User, { foreignKey: 'userId' });

CreditCard.hasMany(Transaction, { foreignKey: 'creditCardId', onDelete: 'SET NULL' });
Transaction.belongsTo(CreditCard, { foreignKey: 'creditCardId' });

module.exports = { User, Category, Transaction, Budget, RecurringRule, CreditCard };
