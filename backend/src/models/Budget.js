const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const Budget = sequelize.define('Budget', {
  id: {
    type: DataTypes.UUID,
    defaultValue: DataTypes.UUIDV4,
    primaryKey: true,
  },
  limitAmount: {
    type: DataTypes.DECIMAL(12, 2),
    allowNull: false,
  },
  period: {
    type: DataTypes.ENUM('weekly', 'monthly', 'yearly'),
    defaultValue: 'monthly',
  },
});

module.exports = Budget;
