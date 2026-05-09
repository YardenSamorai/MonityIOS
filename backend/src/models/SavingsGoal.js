const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const SavingsGoal = sequelize.define('SavingsGoal', {
  id: {
    type: DataTypes.UUID,
    defaultValue: DataTypes.UUIDV4,
    primaryKey: true,
  },
  name: {
    type: DataTypes.STRING(120),
    allowNull: false,
  },
  targetAmount: {
    type: DataTypes.DECIMAL(12, 2),
    allowNull: false,
  },
  currentAmount: {
    type: DataTypes.DECIMAL(12, 2),
    allowNull: false,
    defaultValue: 0,
  },
  currency: {
    type: DataTypes.STRING(3),
    defaultValue: 'ILS',
  },
  targetDate: {
    type: DataTypes.DATEONLY,
    allowNull: true,
  },
  sortOrder: {
    type: DataTypes.INTEGER,
    defaultValue: 0,
  },
});

module.exports = SavingsGoal;
